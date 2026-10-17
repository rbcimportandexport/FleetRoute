import { loadGoogleMaps } from './googleMaps';

// A small bridge for the route planner; the map is rendered by Google's SDK.
export async function createGoogleMapView(container, signal) {
  const maps = await loadGoogleMaps();
  await maps.importLibrary('maps');
  if (signal?.aborted) throw new DOMException('Map initialization cancelled', 'AbortError');
  const map = new maps.Map(container, {
    center: { lat: 22.9734, lng: 78.6569 }, zoom: 5,
    mapTypeId: 'hybrid', mapTypeControl: false, streetViewControl: false,
    fullscreenControl: false, tilt: 0, heading: 0,
    gestureHandling: 'greedy', zoomControl: true, scaleControl: true,
    zoomControlOptions: { position: maps.ControlPosition.RIGHT_BOTTOM },
  });
  const pointLiteral = (point) => Array.isArray(point) ? { lat: point[0], lng: point[1] } : { lat: point.lat, lng: point.lng };
  let routeObjects = [];
  const markers = new Set();
  const clickListeners = new Map();
  let fitListener;
  const cancelFit = () => { fitListener?.remove(); fitListener = null; };

  const trafficLayer = new maps.TrafficLayer();
  trafficLayer.setMap(map);
  let trafficEnabled = true;

  class Pin extends maps.OverlayView {
    constructor(point, letter, title) {
      super();
      this.position = pointLiteral(point);
      this.element = document.createElement('div');
      this.element.className = 'google-route-pin';
      this.element.setAttribute('role', 'img');
      this.element.setAttribute('aria-label', title || letter);
      this.element.title = title || letter;
      const shape = document.createElement('span');
      shape.className = `route-marker ${letter === 'B' ? 'end' : 'start'}`;
      const text = document.createElement('b');
      text.textContent = letter;
      shape.appendChild(text);
      this.element.appendChild(shape);
      markers.add(this);
      this.setMap(map);
    }
    onAdd() { this.getPanes().overlayMouseTarget.appendChild(this.element); }
    draw() {
      const pixel = this.getProjection()?.fromLatLngToDivPixel(new maps.LatLng(this.position));
      if (!pixel) return;
      this.element.style.left = `${pixel.x}px`;
      this.element.style.top = `${pixel.y}px`;
    }
    onRemove() { this.element.remove(); }
    setLatLng(point) { this.position = pointLiteral(point); this.draw(); }
    remove() { this.setMap(null); markers.delete(this); }
  }

  class VehicleMarker extends maps.OverlayView {
    constructor(point, vehicleType = 'car', title = 'Live vehicle location') {
      super();
      this.position = pointLiteral(point);
      this.element = document.createElement('div');
      this.element.className = 'google-vehicle-pin';
      this.element.setAttribute('role', 'img');
      this.element.setAttribute('aria-label', title);
      this.element.innerHTML = `<span class="moving-vehicle vehicle-${vehicleType}"><span class="moving-vehicle-core"></span></span>`;
      markers.add(this);
      this.setMap(map);
    }
    onAdd() { this.getPanes().overlayMouseTarget.appendChild(this.element); }
    draw() {
      const pixel = this.getProjection()?.fromLatLngToDivPixel(new maps.LatLng(this.position));
      if (!pixel) return;
      this.element.style.left = `${pixel.x}px`;
      this.element.style.top = `${pixel.y}px`;
    }
    onRemove() { this.element.remove(); }
    setLatLng(point) { this.position = pointLiteral(point); this.draw(); }
    remove() { this.setMap(null); markers.delete(this); }
  }

  function clearRoute() {
    cancelFit();
    routeObjects.forEach((object) => object instanceof Pin ? object.remove() : object.setMap(null));
    routeObjects = [];
  }

  function fit(points, maxZoom) {
    cancelFit();
    const bounds = new maps.LatLngBounds();
    points.forEach((point) => bounds.extend(pointLiteral(point)));
    map.fitBounds(bounds, 55);
    fitListener = maps.event.addListenerOnce(map, 'idle', () => {
      if (map.getZoom() > maxZoom) map.setZoom(maxZoom);
      fitListener = null;
    });
  }

  return {
    provider: 'google',
    getCenter: () => map.getCenter()?.toJSON(),
    getZoom: () => map.getZoom() || 5,
    getContainer: () => container,
    setStyle: (style) => map.setMapTypeId(style === 'satellite' ? 'hybrid' : 'roadmap'),
    setView(point, zoom) { cancelFit(); map.setCenter(pointLiteral(point)); map.setZoom(zoom); },
    flyTo(point, zoom) { cancelFit(); map.panTo(pointLiteral(point)); if (zoom !== undefined) map.setZoom(zoom); },
    setTraffic(enabled) {
      trafficEnabled = Boolean(enabled);
      trafficLayer.setMap(trafficEnabled ? map : null);
    },
    isTrafficEnabled: () => trafficEnabled,
    toggleTraffic() {
      trafficEnabled = !trafficEnabled;
      trafficLayer.setMap(trafficEnabled ? map : null);
      return trafficEnabled;
    },
    on(event, handler) {
      if (event !== 'click') return;
      clickListeners.set(handler, map.addListener('click', (eventData) => {
        if (eventData.latLng) {
          eventData.stop?.();
          handler({ latlng: eventData.latLng.toJSON() });
        }
      }));
    },
    off(event, handler) { clickListeners.get(handler)?.remove(); clickListeners.delete(handler); },
    drawRoute(origin, destination, route, pinMode) {
      clearRoute();
      if (origin.point) routeObjects.push(new Pin(origin.point, 'A', origin.query));
      if (destination.point) routeObjects.push(new Pin(destination.point, 'B', destination.query));
      [origin, destination].forEach(({ point }) => {
        if (point?.accuracy) routeObjects.push(new maps.Circle({
          map, center: pointLiteral(point), radius: point.accuracy,
          fillColor: '#1769e0', fillOpacity: .12, strokeColor: '#1769e0', strokeWeight: 1,
          clickable: false,
        }));
      });
      if (route?.geometry?.coordinates) {
        const path = route.geometry.coordinates.map(([lng, lat]) => ({ lat, lng }));
        routeObjects.push(new maps.Polyline({ map, path, strokeColor: '#fff', strokeWeight: 9, clickable: false }));
        routeObjects.push(new maps.Polyline({ map, path, strokeColor: '#1769e0', strokeWeight: 5, clickable: false }));
        fit(path, 17);
      } else if (origin.point && destination.point) {
        fit([origin.point, destination.point], 17);
      } else if ((origin.point || destination.point) && !pinMode) {
        map.panTo(pointLiteral(origin.point || destination.point));
        map.setZoom(15);
      }
    },
    createLiveMarker: (point, vehicleType = 'car') => new VehicleMarker(point, vehicleType),
    remove() {
      trafficLayer.setMap(null);
      clearRoute();
      [...markers].forEach((pin) => pin.remove());
      clickListeners.forEach((listener) => listener.remove());
      clickListeners.clear();
      maps.event.clearInstanceListeners(map);
      container.replaceChildren();
    },
  };
}
