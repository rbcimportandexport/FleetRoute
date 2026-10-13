import React, { useState, useEffect } from 'react';
import { 
  X, 
  ArrowLeft, 
  ArrowRight, 
  Check, 
  CheckCircle2, 
  AlertTriangle, 
  User, 
  Truck, 
  MapPin, 
  Plus, 
  Trash2, 
  MoveUp, 
  MoveDown, 
  Calendar, 
  Boxes, 
  Scale, 
  Clock, 
  Phone, 
  ShieldAlert,
  Info,
  Zap,
  SlidersHorizontal,
  Package,
  Layers,
  Sparkles,
  Route
} from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';

const STEP_TITLES = [
  '1. Driver & Vehicle',
  '2. Starting Point',
  '3. Pickup Stops',
  '4. Delivery Stops',
  '5. Cargo Allocation',
  '6. Schedule & Depot',
  '7. Review & Dispatch'
];

export default function TripCreateModal({
  isOpen,
  onClose,
  onCreateTrip,
  drivers = [],
  vehicles = [],
  locations = [],
  products = []
}) {
  // Mode selection: 'express' (default, super easy) vs 'advanced' (7-step multi-stop)
  const [dispatchMode, setDispatchMode] = useState('express');

  // Advanced Step tracker
  const [currentStep, setCurrentStep] = useState(1);
  const [errorMsg, setErrorMsg] = useState('');

  // Common Fleet State
  const [selectedDriverId, setSelectedDriverId] = useState('');
  const [selectedVehicleId, setSelectedVehicleId] = useState('');
  const [startLocationId, setStartLocationId] = useState('');

  // Express Mode Specific State
  const [expressDestinationId, setExpressDestinationId] = useState('');
  const [expressCargoPreset, setExpressCargoPreset] = useState('standard');
  const [expressCargoName, setExpressCargoName] = useState('General Commercial Packages');
  const [expressQty, setExpressQty] = useState('10');
  const [expressWeightKg, setExpressWeightKg] = useState('15');
  const [expressRecipientName, setExpressRecipientName] = useState('Authorized Store Contact');
  const [expressRecipientPhone, setExpressRecipientPhone] = useState('+91 98000 11224');
  const [expressReturnDepot, setExpressReturnDepot] = useState(false);

  // Advanced Step 3: Pickup Stops
  const [pickupStops, setPickupStops] = useState([
    {
      id: 'p-1',
      locationId: '',
      recipientName: 'Warehouse Supervisor',
      recipientPhone: '+91 98000 11223',
      plannedArrival: '08:30 AM',
      estimatedDurationMinutes: 25,
      cargoSummary: 'Load 12 Office Chairs + 3 Massage Chairs'
    }
  ]);

  // Advanced Step 4: Delivery Stops
  const [deliveryStops, setDeliveryStops] = useState([
    {
      id: 'd-1',
      locationId: '',
      recipientName: 'Operations Lead - Stop A',
      recipientPhone: '+91 98000 11224',
      plannedArrival: '09:45 AM',
      estimatedDurationMinutes: 15,
      cargoSummary: 'Deliver 5 Office Chairs'
    },
    {
      id: 'd-2',
      locationId: '',
      recipientName: 'Facilities Lead - Stop B',
      recipientPhone: '+91 98000 11225',
      plannedArrival: '11:00 AM',
      estimatedDurationMinutes: 15,
      cargoSummary: 'Deliver 7 Office Chairs'
    },
    {
      id: 'd-3',
      locationId: '',
      recipientName: 'Studio Owner - Stop C',
      recipientPhone: '+91 98000 11226',
      plannedArrival: '12:15 PM',
      estimatedDurationMinutes: 15,
      cargoSummary: 'Deliver 3 Massage Chairs'
    }
  ]);

  // Advanced Step 5: Cargo Allocation
  const [cargoItems, setCargoItems] = useState([
    {
      productId: 'PRD-01',
      productName: 'Ergonomic Office Mesh Chair',
      category: 'OFFICE_FURNITURE',
      plannedQty: 12,
      weightKg: 15,
      fragile: false
    },
    {
      productId: 'PRD-02',
      productName: 'Luxury Zero-Gravity Massage Chair',
      category: 'MASSAGE_CHAIRS',
      plannedQty: 3,
      weightKg: 85,
      fragile: true
    }
  ]);

  // Advanced Step 6: Schedule & Depot
  const [plannedDeparture, setPlannedDeparture] = useState('2026-10-12T08:00');
  const [priority, setPriority] = useState('standard');
  const [dispatcherNotes, setDispatcherNotes] = useState('Multi-stop logistics route with verified cargo balances.');
  const [returnDepotLocationId, setReturnDepotLocationId] = useState('');

  // Initial defaults
  useEffect(() => {
    if (drivers.length > 0 && !selectedDriverId) {
      setSelectedDriverId(drivers[0].id);
    }
    if (vehicles.length > 0 && !selectedVehicleId) {
      setSelectedVehicleId(vehicles[0].id);
    }
    if (locations.length > 0) {
      if (!startLocationId) setStartLocationId(locations[0].id);
      if (!expressDestinationId) {
        setExpressDestinationId(locations[1]?.id || locations[0].id);
      }
      if (pickupStops[0] && !pickupStops[0].locationId) {
        setPickupStops(prev => prev.map((p, i) => i === 0 ? { ...p, locationId: locations[1]?.id || locations[0].id } : p));
      }
      if (deliveryStops[0] && !deliveryStops[0].locationId) {
        setDeliveryStops(prev => prev.map((d, i) => ({
          ...d,
          locationId: locations[i + 2]?.id || locations[0].id
        })));
      }
      if (!returnDepotLocationId) {
        const depot = locations.find(l => l.type === 'depot' || l.type === 'driver_base');
        setReturnDepotLocationId(depot ? depot.id : locations[0].id);
      }
    }
  }, [drivers, vehicles, locations]);

  if (!isOpen) return null;

  const selectedDriver = drivers.find(d => d.id === selectedDriverId);
  const selectedVehicle = vehicles.find(v => v.id === selectedVehicleId);
  const startLoc = locations.find(l => l.id === startLocationId) || locations[0];
  const expressDestLoc = locations.find(l => l.id === expressDestinationId) || locations[1] || locations[0];

  // Capacity calculation
  const totalCargoWeight = cargoItems.reduce((acc, c) => acc + (parseFloat(c.weightKg) || 0) * (parseInt(c.plannedQty, 10) || 0), 0);
  const vehicleMaxPayload = selectedVehicle?.maxWeightKg || selectedVehicle?.capacityKg || 1500;
  const isWeightOverload = totalCargoWeight > vehicleMaxPayload;

  // 1-Click Route Presets for Fast Setup
  const applyPreset = (presetType) => {
    soundEffects.playActionClick();
    setErrorMsg('');

    if (presetType === 'single_drop') {
      const dropLoc = locations[1] || locations[0] || {};
      setPickupStops([
        {
          id: 'p-1',
          locationId: startLoc?.id || locations[0]?.id || '',
          recipientName: 'Warehouse Base Officer',
          recipientPhone: startLoc?.contactPhone || '+91 98000 11223',
          plannedArrival: '09:00 AM',
          estimatedDurationMinutes: 20,
          cargoSummary: 'Load single-destination consignment'
        }
      ]);
      setDeliveryStops([
        {
          id: 'd-1',
          locationId: dropLoc.id || '',
          recipientName: dropLoc.contactName || 'Branch Manager',
          recipientPhone: dropLoc.contactPhone || '+91 98000 11224',
          plannedArrival: '11:30 AM',
          estimatedDurationMinutes: 20,
          cargoSummary: 'Deliver commercial shipment'
        }
      ]);
      setCargoItems([
        {
          productId: 'PRD-01',
          productName: 'Commercial Parcel Consignment',
          category: 'EXPRESS_PARCEL',
          plannedQty: 15,
          weightKg: 20,
          fragile: false
        }
      ]);
      setReturnDepotLocationId('');
      setCurrentStep(7); // Jump straight to review!
    } else if (presetType === 'city_3_stop') {
      setPickupStops([
        {
          id: 'p-1',
          locationId: startLoc?.id || locations[0]?.id || '',
          recipientName: 'Central Warehouse Lead',
          recipientPhone: '+91 98000 11223',
          plannedArrival: '08:30 AM',
          estimatedDurationMinutes: 25,
          cargoSummary: 'Load Multi-Drop City Freight'
        }
      ]);
      setDeliveryStops([
        {
          id: 'd-1',
          locationId: locations[1]?.id || locations[0]?.id,
          recipientName: 'Store Lead - Stop A',
          recipientPhone: '+91 98000 11224',
          plannedArrival: '10:00 AM',
          estimatedDurationMinutes: 15,
          cargoSummary: 'Deliver Retail Stock (Drop 1)'
        },
        {
          id: 'd-2',
          locationId: locations[2]?.id || locations[1]?.id || locations[0]?.id,
          recipientName: 'Facilities Lead - Stop B',
          recipientPhone: '+91 98000 11225',
          plannedArrival: '11:45 AM',
          estimatedDurationMinutes: 15,
          cargoSummary: 'Deliver Office Supplies (Drop 2)'
        },
        {
          id: 'd-3',
          locationId: locations[3]?.id || locations[1]?.id || locations[0]?.id,
          recipientName: 'Site Supervisor - Stop C',
          recipientPhone: '+91 98000 11226',
          plannedArrival: '01:15 PM',
          estimatedDurationMinutes: 15,
          cargoSummary: 'Deliver Equipment (Drop 3)'
        }
      ]);
      setCurrentStep(7); // Jump to review!
    } else if (presetType === 'depot_roundtrip') {
      const depot = locations.find(l => l.type === 'depot') || locations[0] || {};
      setReturnDepotLocationId(depot.id);
    }
  };

  // Express Dispatch Handler (1-Screen, 1-Click Submission)
  const handleExpressDispatch = (e) => {
    e?.preventDefault();
    soundEffects.playActionClick();
    setErrorMsg('');

    if (!selectedDriverId || !selectedVehicleId) {
      setErrorMsg('Please select a driver and vehicle.');
      return;
    }

    const startLocation = locations.find(l => l.id === startLocationId) || locations[0];
    const destinationLocation = locations.find(l => l.id === expressDestinationId) || locations[1] || locations[0];

    if (!startLocation || !destinationLocation) {
      setErrorMsg('Please ensure both origin and delivery destinations are selected.');
      return;
    }

    const qty = parseInt(expressQty, 10) || 10;
    const unitWeight = parseFloat(expressWeightKg) || 15;
    const totalWt = qty * unitWeight;

    if (totalWt > vehicleMaxPayload) {
      setErrorMsg(`Total weight (${totalWt} kg) exceeds vehicle capacity rating (${vehicleMaxPayload} kg).`);
      return;
    }

    const formattedStops = [
      {
        stopIndex: 0,
        type: 'pickup',
        locationId: startLocation.id,
        location: startLocation,
        name: startLocation.name || 'Origin Base',
        address: startLocation.address || '',
        lat: startLocation.lat,
        lng: startLocation.lng,
        recipientName: 'Fleet Base Officer',
        recipientPhone: startLocation.contactPhone || '+91 98000 00000',
        plannedArrival: '08:30 AM',
        cargoSummary: `Inspect Vehicle & Load ${qty} units of ${expressCargoName}`
      },
      {
        stopIndex: 1,
        type: 'delivery',
        locationId: destinationLocation.id,
        location: destinationLocation,
        name: destinationLocation.name || 'Destination Dropoff',
        address: destinationLocation.address || '',
        lat: destinationLocation.lat,
        lng: destinationLocation.lng,
        recipientName: expressRecipientName.trim() || destinationLocation.contactName || 'Authorized Signatory',
        recipientPhone: expressRecipientPhone.trim() || destinationLocation.contactPhone || '+91 98000 11224',
        plannedArrival: '11:30 AM',
        cargoSummary: `Deliver ${qty} units of ${expressCargoName}`
      }
    ];

    if (expressReturnDepot) {
      formattedStops.push({
        stopIndex: 2,
        type: 'return',
        locationId: startLocation.id,
        location: startLocation,
        name: startLocation.name || 'Depot Return Bay',
        address: startLocation.address || '',
        lat: startLocation.lat,
        lng: startLocation.lng,
        recipientName: 'Depot Gate Officer',
        recipientPhone: startLocation.contactPhone || '+91 98000 00000',
        plannedArrival: '02:00 PM',
        cargoSummary: 'Depot Return & Reconciliation'
      });
    }

    const cargoPayload = [
      {
        productId: 'PRD-EXPRESS-1',
        productName: expressCargoName.trim() || 'General Commercial Cargo',
        category: 'EXPRESS_DELIVERY',
        plannedQty: qty,
        weightKg: unitWeight,
        fragile: false
      }
    ];

    onCreateTrip({
      driverId: selectedDriverId,
      vehicleId: selectedVehicleId,
      plannedDeparture: plannedDeparture || new Date().toISOString(),
      priority,
      dispatcherNotes: dispatcherNotes || 'Express 1-Click Dispatched Route.',
      stops: formattedStops,
      cargo: cargoPayload
    });

    soundEffects.playSuccessChime();
    onClose();
  };

  // Validate and advance step in Advanced Mode
  const handleNextStep = () => {
    setErrorMsg('');

    if (currentStep === 1) {
      if (!selectedDriverId || !selectedVehicleId) {
        setErrorMsg('Please select an assigned driver and vehicle.');
        return;
      }
    } else if (currentStep === 2) {
      if (!startLocationId) {
        setErrorMsg('Please select a starting origin location.');
        return;
      }
    } else if (currentStep === 3) {
      if (pickupStops.length === 0 || pickupStops.some(p => !p.locationId)) {
        setErrorMsg('Please configure at least one pickup waypoint with a valid location.');
        return;
      }
    } else if (currentStep === 4) {
      if (deliveryStops.length === 0 || deliveryStops.some(d => !d.locationId)) {
        setErrorMsg('Please configure at least one delivery destination with a valid location.');
        return;
      }
    } else if (currentStep === 5) {
      if (cargoItems.length === 0 || cargoItems.some(c => !c.plannedQty || c.plannedQty <= 0)) {
        setErrorMsg('All cargo items must have positive planned quantities.');
        return;
      }
      if (isWeightOverload) {
        setErrorMsg(`Total cargo weight (${totalCargoWeight} kg) exceeds vehicle payload rating (${vehicleMaxPayload} kg).`);
        return;
      }
    }

    soundEffects.playActionClick();
    setCurrentStep(prev => Math.min(prev + 1, 7));
  };

  const handlePrevStep = () => {
    setErrorMsg('');
    soundEffects.playActionClick();
    setCurrentStep(prev => Math.max(prev - 1, 1));
  };

  // Reorder delivery stops
  const moveDeliveryStop = (index, direction) => {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= deliveryStops.length) return;

    soundEffects.playActionClick();
    const updated = [...deliveryStops];
    const temp = updated[index];
    updated[index] = updated[targetIndex];
    updated[targetIndex] = temp;
    setDeliveryStops(updated);
  };

  // Add delivery stop
  const handleAddDeliveryStop = () => {
    soundEffects.playActionClick();
    const newIdx = deliveryStops.length + 1;
    setDeliveryStops([
      ...deliveryStops,
      {
        id: `d-${Date.now()}`,
        locationId: locations[newIdx % locations.length]?.id || locations[0]?.id || '',
        recipientName: `Authorized Contact - Stop ${newIdx}`,
        recipientPhone: '+91 98000 00000',
        plannedArrival: `${12 + newIdx}:00 PM`,
        estimatedDurationMinutes: 15,
        cargoSummary: 'General Delivery Drop'
      }
    ]);
  };

  const handleRemoveDeliveryStop = (index) => {
    if (deliveryStops.length <= 1) return;
    soundEffects.playActionClick();
    setDeliveryStops(deliveryStops.filter((_, i) => i !== index));
  };

  // Final Dispatch in Advanced Mode
  const handleFinalDispatch = (e) => {
    e.preventDefault();
    soundEffects.playActionClick();

    const formattedStops = [];

    // Origin
    formattedStops.push({
      stopIndex: 0,
      type: 'pickup',
      locationId: startLoc?.id,
      location: startLoc,
      name: startLoc?.name || 'Driver Origin Base',
      address: startLoc?.address || '',
      lat: startLoc?.lat,
      lng: startLoc?.lng,
      recipientName: 'Fleet Base Officer',
      recipientPhone: startLoc?.contactPhone || '+91 98000 00000',
      plannedArrival: '08:00 AM',
      cargoSummary: 'Departure Point & Pre-Trip Inspection'
    });

    // Pickups
    pickupStops.forEach((p, idx) => {
      const loc = locations.find(l => l.id === p.locationId) || locations[0];
      formattedStops.push({
        stopIndex: formattedStops.length,
        type: 'pickup',
        locationId: loc?.id,
        location: loc,
        name: loc?.name || `Pickup Stop ${idx + 1}`,
        address: loc?.address || '',
        lat: loc?.lat,
        lng: loc?.lng,
        recipientName: p.recipientName,
        recipientPhone: p.recipientPhone,
        plannedArrival: p.plannedArrival,
        cargoSummary: p.cargoSummary
      });
    });

    // Deliveries
    deliveryStops.forEach((d, idx) => {
      const loc = locations.find(l => l.id === d.locationId) || locations[0];
      formattedStops.push({
        stopIndex: formattedStops.length,
        type: 'delivery',
        locationId: loc?.id,
        location: loc,
        name: loc?.name || `Delivery Stop ${String.fromCharCode(65 + idx)}`,
        address: loc?.address || '',
        lat: loc?.lat,
        lng: loc?.lng,
        recipientName: d.recipientName,
        recipientPhone: d.recipientPhone,
        plannedArrival: d.plannedArrival,
        cargoSummary: d.cargoSummary
      });
    });

    // Optional Depot Return
    if (returnDepotLocationId) {
      const depotLoc = locations.find(l => l.id === returnDepotLocationId);
      if (depotLoc) {
        formattedStops.push({
          stopIndex: formattedStops.length,
          type: 'return',
          locationId: depotLoc.id,
          location: depotLoc,
          name: depotLoc.name || 'Depot Return Bay',
          address: depotLoc.address || '',
          lat: depotLoc.lat,
          lng: depotLoc.lng,
          recipientName: 'Depot Return Gate Supervisor',
          recipientPhone: depotLoc.contactPhone || '+91 98000 11999',
          plannedArrival: '02:00 PM',
          cargoSummary: 'Depot Return & Reconciliation'
        });
      }
    }

    onCreateTrip({
      driverId: selectedDriverId,
      vehicleId: selectedVehicleId,
      plannedDeparture,
      priority,
      dispatcherNotes,
      stops: formattedStops,
      cargo: cargoItems
    });

    soundEffects.playSuccessChime();
    onClose();
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      background: 'rgba(15, 23, 42, 0.65)',
      backdropFilter: 'blur(4px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '8px',
      zIndex: 9999
    }}>
      <div className="trip-modal-container">
        
        {/* Header with Mode Switcher & Close */}
        <div className="trip-modal-header">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
            <div>
              <h2 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--navy-900)', letterSpacing: '-0.01em', display: 'flex', alignItems: 'center', gap: '8px' }}>
                {dispatchMode === 'express' ? <Zap size={18} color="var(--primary-blue)" /> : <Route size={18} color="var(--primary-teal)" />}
                <span>{dispatchMode === 'express' ? 'Quick Dispatch' : 'Multi-Stop Route Dispatcher'}</span>
              </h2>
              <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '1px' }}>
                {dispatchMode === 'express' 
                  ? 'Dispatch a driver & delivery in 30 seconds' 
                  : `Step ${currentStep} of 7: ${STEP_TITLES[currentStep - 1]}`}
              </div>
            </div>

            <button
              onClick={onClose}
              style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer', padding: '6px' }}
              title="Close modal"
            >
              <X size={20} />
            </button>
          </div>

          {/* Mode Switcher Tabs */}
          <div style={{
            display: 'flex',
            background: 'var(--slate-100)',
            borderRadius: '10px',
            padding: '3px',
            gap: '4px'
          }}>
            <button
              type="button"
              onClick={() => { setDispatchMode('express'); setErrorMsg(''); soundEffects.playActionClick(); }}
              className="trip-mode-pill"
              style={{
                background: dispatchMode === 'express' ? '#ffffff' : 'transparent',
                color: dispatchMode === 'express' ? 'var(--primary-blue)' : 'var(--slate-600)',
                boxShadow: dispatchMode === 'express' ? '0 1px 4px rgba(0,0,0,0.08)' : 'none'
              }}
            >
              <Zap size={14} />
              <span>Quick Dispatch (Express)</span>
            </button>

            <button
              type="button"
              onClick={() => { setDispatchMode('advanced'); setErrorMsg(''); soundEffects.playActionClick(); }}
              className="trip-mode-pill"
              style={{
                background: dispatchMode === 'advanced' ? '#ffffff' : 'transparent',
                color: dispatchMode === 'advanced' ? 'var(--navy-900)' : 'var(--slate-600)',
                boxShadow: dispatchMode === 'advanced' ? '0 1px 4px rgba(0,0,0,0.08)' : 'none'
              }}
            >
              <SlidersHorizontal size={14} />
              <span>Advanced Multi-Stop (7 Steps)</span>
            </button>
          </div>

          {/* In Advanced Mode: Clickable Step Pills */}
          {dispatchMode === 'advanced' && (
            <div style={{ marginTop: '12px' }}>
              <div style={{ display: 'flex', gap: '4px', overflowX: 'auto', paddingBottom: '4px' }}>
                {STEP_TITLES.map((title, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => { setErrorMsg(''); setCurrentStep(idx + 1); soundEffects.playActionClick(); }}
                    className={`step-pill-clickable ${currentStep === idx + 1 ? 'active' : ''}`}
                    title={title}
                  >
                    <span style={{
                      width: '18px',
                      height: '18px',
                      borderRadius: '50%',
                      background: currentStep === idx + 1 ? 'var(--primary-blue)' : (currentStep > idx + 1 ? 'var(--status-emerald)' : 'var(--slate-200)'),
                      color: (currentStep >= idx + 1) ? '#ffffff' : 'var(--slate-600)',
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '10px',
                      fontWeight: 800
                    }}>
                      {idx + 1}
                    </span>
                    <span>{title.split('. ')[1]}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Modal Content Body */}
        <div className="trip-modal-body">
          
          {errorMsg && (
            <div style={{
              background: 'var(--status-rose-light)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              borderRadius: '8px',
              padding: '10px 14px',
              color: 'var(--status-rose-text)',
              fontSize: '12px',
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              marginBottom: '16px'
            }}>
              <AlertTriangle size={16} style={{ flexShrink: 0 }} />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* ========================================================
              EXPRESS DISPATCH MODE (1-Screen, 30-Second Trip Creation)
              ======================================================== */}
          {dispatchMode === 'express' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              
              {/* Fleet Selection */}
              <div className="trip-form-grid-2">
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Driver *
                  </label>
                  <select
                    value={selectedDriverId}
                    onChange={(e) => setSelectedDriverId(e.target.value)}
                    className="form-control"
                  >
                    {drivers.map(d => (
                      <option key={d.id} value={d.id}>
                        {d.name} ({d.availability || 'Available'}) - {d.phone}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Vehicle *
                  </label>
                  <select
                    value={selectedVehicleId}
                    onChange={(e) => setSelectedVehicleId(e.target.value)}
                    className="form-control"
                  >
                    {vehicles.map(v => (
                      <option key={v.id} value={v.id}>
                        {v.registrationNumber} - {v.model} ({v.capacityKg || 1500} kg cap)
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Route Waypoints (From -> To) */}
              <div className="trip-form-grid-2">
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    1. Origin / Pickup Location *
                  </label>
                  <select
                    value={startLocationId}
                    onChange={(e) => setStartLocationId(e.target.value)}
                    className="form-control"
                  >
                    {locations.map(l => (
                      <option key={l.id} value={l.id}>
                        {l.name} ({l.address})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    2. Destination / Delivery Location *
                  </label>
                  <select
                    value={expressDestinationId}
                    onChange={(e) => setExpressDestinationId(e.target.value)}
                    className="form-control"
                  >
                    {locations.map(l => (
                      <option key={l.id} value={l.id}>
                        {l.name} ({l.address})
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Recipient Details */}
              <div className="trip-form-grid-2">
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Recipient / Onsite Contact Person
                  </label>
                  <input
                    type="text"
                    value={expressRecipientName}
                    onChange={(e) => setExpressRecipientName(e.target.value)}
                    placeholder="e.g. Ramesh Kumar (Store Manager)"
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Recipient Phone Number
                  </label>
                  <input
                    type="text"
                    value={expressRecipientPhone}
                    onChange={(e) => setExpressRecipientPhone(e.target.value)}
                    placeholder="+91 98000 11224"
                    className="form-control"
                  />
                </div>
              </div>

              {/* Cargo Details */}
              <div style={{
                background: 'var(--slate-50)',
                padding: '14px',
                borderRadius: '12px',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Boxes size={15} color="var(--primary-blue)" />
                  <span>Cargo To Deliver</span>
                </div>

                {/* Quick Cargo Category Presets */}
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginBottom: '10px' }}>
                  {[
                    { label: 'Commercial Packages', name: 'Commercial Parcel Consignment', qty: '15', wt: '10' },
                    { label: 'Office Furniture', name: 'Ergonomic Office Mesh Chairs', qty: '10', wt: '15' },
                    { label: 'Electronics & IT', name: 'Server & IT Electronics Units', qty: '5', wt: '25' },
                    { label: 'Priority Medical', name: 'Priority Medical Deliveries', qty: '8', wt: '12' }
                  ].map(cp => (
                    <button
                      key={cp.label}
                      type="button"
                      onClick={() => {
                        setExpressCargoName(cp.name);
                        setExpressQty(cp.qty);
                        setExpressWeightKg(cp.wt);
                        soundEffects.playActionClick();
                      }}
                      className="trip-preset-pill"
                    >
                      <span>{cp.label}</span>
                    </button>
                  ))}
                </div>

                <div className="trip-form-grid-3">
                  <div style={{ gridColumn: 'span 2' }}>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>
                      Cargo Description
                    </label>
                    <input
                      type="text"
                      value={expressCargoName}
                      onChange={(e) => setExpressCargoName(e.target.value)}
                      placeholder="e.g. Office Chairs, Cartons, Equipment"
                      className="form-control"
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>
                      Quantity (Units)
                    </label>
                    <input
                      type="number"
                      min="1"
                      value={expressQty}
                      onChange={(e) => setExpressQty(e.target.value)}
                      className="form-control"
                    />
                  </div>
                </div>

                <div style={{ marginTop: '8px', fontSize: '11.5px', color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span>Est. Payload: <strong>{(parseInt(expressQty, 10) || 0) * (parseFloat(expressWeightKg) || 0)} kg</strong></span>
                  <span>Vehicle Rating: <strong>{vehicleMaxPayload} kg</strong></span>
                </div>
              </div>

              {/* Depot Return Option */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 0' }}>
                <input
                  type="checkbox"
                  id="expressReturnDepot"
                  checked={expressReturnDepot}
                  onChange={(e) => setExpressReturnDepot(e.target.checked)}
                  style={{ width: '16px', height: '16px', accentColor: 'var(--primary-blue)', cursor: 'pointer' }}
                />
                <label htmlFor="expressReturnDepot" style={{ fontSize: '12.5px', fontWeight: 600, color: 'var(--navy-800)', cursor: 'pointer' }}>
                  Roundtrip: Return to origin base after delivery completed
                </label>
              </div>

              {/* Express Notice */}
              <div style={{
                fontSize: '11.5px',
                color: 'var(--slate-500)',
                background: 'var(--sky-blue-light)',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid rgba(2, 132, 199, 0.2)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}>
                <span>Need 3+ stops or custom waypoints?</span>
                <button
                  type="button"
                  onClick={() => { setDispatchMode('advanced'); soundEffects.playActionClick(); }}
                  style={{ background: 'none', border: 'none', color: 'var(--primary-blue)', fontWeight: 700, cursor: 'pointer', fontSize: '11.5px' }}
                >
                  Switch to Multi-Stop Planner →
                </button>
              </div>

            </div>
          ) : (
            /* ========================================================
               ADVANCED 7-STEP MULTI-STOP WIZARD
               ======================================================== */
            <>
              {/* Presets Bar in Advanced Mode */}
              <div style={{
                background: 'var(--slate-50)',
                padding: '10px 14px',
                borderRadius: '10px',
                border: '1px solid var(--slate-200)',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: '8px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11.5px', fontWeight: 700, color: 'var(--navy-800)' }}>
                  <Sparkles size={14} color="var(--primary-blue)" />
                  <span>1-Click Route Presets:</span>
                </div>

                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={() => applyPreset('single_drop')}
                    className="trip-preset-pill"
                  >
                    <Zap size={12} color="var(--primary-blue)" />
                    <span>Single-Drop Express</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => applyPreset('city_3_stop')}
                    className="trip-preset-pill"
                  >
                    <Route size={12} color="var(--primary-teal)" />
                    <span>3-Stop City Run</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => applyPreset('depot_roundtrip')}
                    className="trip-preset-pill"
                  >
                    <CheckCircle2 size={12} color="var(--status-emerald)" />
                    <span>Add Depot Return</span>
                  </button>
                </div>
              </div>

              {/* STEP 1: DRIVER & VEHICLE */}
              {currentStep === 1 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div>
                    <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                      Step 1: Select Driver &amp; Commercial Vehicle
                    </h3>
                    <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                      Assign an available qualified driver and transport vehicle for this dispatch.
                    </p>
                  </div>

                  <div className="trip-form-grid-2">
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                        Commercial Driver *
                      </label>
                      <select
                        value={selectedDriverId}
                        onChange={(e) => setSelectedDriverId(e.target.value)}
                        className="form-control"
                      >
                        {drivers.map(d => (
                          <option key={d.id} value={d.id}>
                            {d.name} ({d.availability || 'Available'}) - {d.phone}
                          </option>
                        ))}
                      </select>

                      {selectedDriver && (
                        <div style={{ background: 'var(--slate-50)', padding: '10px', borderRadius: '8px', marginTop: '8px', fontSize: '11px', border: '1px solid var(--slate-200)' }}>
                          <div>License: <strong>{selectedDriver.licenseNumber}</strong></div>
                          <div>Status: <strong style={{ textTransform: 'capitalize' }}>{selectedDriver.availability || 'Available'}</strong></div>
                        </div>
                      )}
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                        Transport Vehicle Asset *
                      </label>
                      <select
                        value={selectedVehicleId}
                        onChange={(e) => setSelectedVehicleId(e.target.value)}
                        className="form-control"
                      >
                        {vehicles.map(v => (
                          <option key={v.id} value={v.id}>
                            {v.registrationNumber} - {v.model} ({v.type})
                          </option>
                        ))}
                      </select>

                      {selectedVehicle && (
                        <div style={{ background: 'var(--slate-50)', padding: '10px', borderRadius: '8px', marginTop: '8px', fontSize: '11px', border: '1px solid var(--slate-200)' }}>
                          <div>Max Payload: <strong>{vehicleMaxPayload} kg</strong></div>
                          <div>Fuel Type: <strong style={{ textTransform: 'capitalize' }}>{selectedVehicle.fuelType || 'Diesel'}</strong></div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}

              {/* STEP 2: STARTING POINT */}
              {currentStep === 2 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div>
                    <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                      Step 2: Starting Depot &amp; Pre-Trip Origin Base
                    </h3>
                    <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                      Select the origin facility where vehicle pre-trip inspection and route departure initiates.
                    </p>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Origin Location *
                    </label>
                    <select
                      value={startLocationId}
                      onChange={(e) => setStartLocationId(e.target.value)}
                      className="form-control"
                    >
                      {locations.map(l => (
                        <option key={l.id} value={l.id}>
                          {l.name} - {l.address} ({l.type})
                        </option>
                      ))}
                    </select>

                    {startLoc && (
                      <div style={{ background: 'var(--slate-50)', padding: '12px', borderRadius: '8px', marginTop: '10px', fontSize: '12px', border: '1px solid var(--slate-200)' }}>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>{startLoc.name}</div>
                        <div style={{ color: 'var(--slate-500)', marginTop: '2px' }}>{startLoc.address}</div>
                        <div style={{ color: 'var(--slate-400)', fontSize: '11px', marginTop: '4px' }}>
                          Coordinates: {Number(startLoc?.lat || 0).toFixed(5)}, {Number(startLoc?.lng || 0).toFixed(5)} | Radius: {startLoc?.arrivalRadiusMeters || 150}m
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* STEP 3: PICKUP STOPS */}
              {currentStep === 3 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                        Step 3: Loading &amp; Pickup Waypoints
                      </h3>
                      <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                        Define distribution centers or vendor locations where freight is collected.
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={() => setPickupStops([...pickupStops, {
                        id: `p-${Date.now()}`,
                        locationId: locations[0]?.id || '',
                        recipientName: 'Warehouse Supervisor',
                        recipientPhone: '+91 98000 11223',
                        plannedArrival: '09:00 AM',
                        estimatedDurationMinutes: 20,
                        cargoSummary: 'Load Scheduled Items'
                      }])}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Plus size={14} />
                      <span>Add Pickup</span>
                    </button>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {pickupStops.map((stop, idx) => (
                      <div key={stop.id} style={{ border: '1px solid var(--slate-200)', borderRadius: '10px', padding: '14px', background: '#ffffff' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                          <span style={{ fontSize: '12px', fontWeight: 800, color: 'var(--primary-teal)' }}>
                            Pickup Waypoint #{idx + 1}
                          </span>
                          {pickupStops.length > 1 && (
                            <button
                              type="button"
                              onClick={() => setPickupStops(pickupStops.filter((_, i) => i !== idx))}
                              style={{ background: 'none', border: 'none', color: 'var(--status-rose)', cursor: 'pointer', padding: '2px' }}
                            >
                              <Trash2 size={14} />
                            </button>
                          )}
                        </div>

                        <div className="trip-form-grid-2">
                          <div>
                            <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '4px' }}>
                              Pickup Location
                            </label>
                            <select
                              value={stop.locationId}
                              onChange={(e) => {
                                const updated = [...pickupStops];
                                updated[idx].locationId = e.target.value;
                                setPickupStops(updated);
                              }}
                              className="form-control"
                            >
                              {locations.map(l => (
                                <option key={l.id} value={l.id}>
                                  {l.name} - {l.address}
                                </option>
                              ))}
                            </select>
                          </div>

                          <div>
                            <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '4px' }}>
                              Cargo Action Summary
                            </label>
                            <input
                              type="text"
                              value={stop.cargoSummary}
                              onChange={(e) => {
                                const updated = [...pickupStops];
                                updated[idx].cargoSummary = e.target.value;
                                setPickupStops(updated);
                              }}
                              className="form-control"
                            />
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* STEP 4: DELIVERY STOPS */}
              {currentStep === 4 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                        Step 4: Delivery Drops &amp; Recipient Hand-Offs
                      </h3>
                      <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                        Add client locations and reorder stops for optimal dispatch routing.
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={handleAddDeliveryStop}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Plus size={14} />
                      <span>Add Delivery Stop</span>
                    </button>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    {deliveryStops.map((stop, idx) => (
                      <div key={stop.id} style={{ border: '1px solid var(--slate-200)', borderRadius: '10px', padding: '12px', background: '#ffffff' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
                          <span style={{ fontSize: '12px', fontWeight: 800, color: 'var(--primary-blue)' }}>
                            Delivery Stop {String.fromCharCode(65 + idx)} (Sequence #{idx + 1})
                          </span>

                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <button
                              type="button"
                              onClick={() => moveDeliveryStop(idx, -1)}
                              disabled={idx === 0}
                              style={{ background: 'var(--slate-100)', border: 'none', borderRadius: '4px', padding: '4px', cursor: idx === 0 ? 'not-allowed' : 'pointer', opacity: idx === 0 ? 0.4 : 1 }}
                              title="Move stop earlier"
                            >
                              <MoveUp size={13} />
                            </button>
                            <button
                              type="button"
                              onClick={() => moveDeliveryStop(idx, 1)}
                              disabled={idx === deliveryStops.length - 1}
                              style={{ background: 'var(--slate-100)', border: 'none', borderRadius: '4px', padding: '4px', cursor: idx === deliveryStops.length - 1 ? 'not-allowed' : 'pointer', opacity: idx === deliveryStops.length - 1 ? 0.4 : 1 }}
                              title="Move stop later"
                            >
                              <MoveDown size={13} />
                            </button>
                            {deliveryStops.length > 1 && (
                              <button
                                type="button"
                                onClick={() => handleRemoveDeliveryStop(idx)}
                                style={{ background: 'none', border: 'none', color: 'var(--status-rose)', cursor: 'pointer', padding: '4px' }}
                                title="Remove stop"
                              >
                                <Trash2 size={14} />
                              </button>
                            )}
                          </div>
                        </div>

                        <div className="trip-form-grid-3">
                          <div>
                            <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>
                              Customer Destination
                            </label>
                            <select
                              value={stop.locationId}
                              onChange={(e) => {
                                const updated = [...deliveryStops];
                                updated[idx].locationId = e.target.value;
                                setDeliveryStops(updated);
                              }}
                              className="form-control"
                            >
                              {locations.map(l => (
                                <option key={l.id} value={l.id}>
                                  {l.name} - {l.address}
                                </option>
                              ))}
                            </select>
                          </div>

                          <div>
                            <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>
                              Recipient Contact Name
                            </label>
                            <input
                              type="text"
                              value={stop.recipientName}
                              onChange={(e) => {
                                const updated = [...deliveryStops];
                                updated[idx].recipientName = e.target.value;
                                setDeliveryStops(updated);
                              }}
                              className="form-control"
                            />
                          </div>

                          <div>
                            <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>
                              Cargo Summary
                            </label>
                            <input
                              type="text"
                              value={stop.cargoSummary}
                              onChange={(e) => {
                                const updated = [...deliveryStops];
                                updated[idx].cargoSummary = e.target.value;
                                setDeliveryStops(updated);
                              }}
                              className="form-control"
                            />
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* STEP 5: CARGO ALLOCATION */}
              {currentStep === 5 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                        Step 5: Cargo Allocation &amp; Weight Validation
                      </h3>
                      <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                        Ensure cargo weights are within commercial vehicle payload capacity.
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={() => setCargoItems([...cargoItems, {
                        productId: `PRD-${Date.now()}`,
                        productName: 'Commercial Freight Items',
                        category: 'GENERAL_FREIGHT',
                        plannedQty: 10,
                        weightKg: 20,
                        fragile: false
                      }])}
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Plus size={14} />
                      <span>Add Item</span>
                    </button>
                  </div>

                  {/* Weight Capacity Card */}
                  <div style={{
                    padding: '12px 16px',
                    borderRadius: '10px',
                    border: `1px solid ${isWeightOverload ? 'var(--status-rose)' : 'var(--slate-200)'}`,
                    background: isWeightOverload ? 'var(--status-rose-light)' : 'var(--slate-50)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between'
                  }}>
                    <div>
                      <div style={{ fontSize: '11px', fontWeight: 700, color: isWeightOverload ? 'var(--status-rose-text)' : 'var(--slate-500)', textTransform: 'uppercase' }}>
                        Cargo Weight Status
                      </div>
                      <div style={{ fontSize: '14px', fontWeight: 800, color: isWeightOverload ? 'var(--status-rose-text)' : 'var(--navy-800)', marginTop: '2px' }}>
                        Total Payload: {totalCargoWeight} kg / Rating: {vehicleMaxPayload} kg
                      </div>
                    </div>

                    <span style={{
                      fontSize: '11px',
                      fontWeight: 800,
                      padding: '3px 8px',
                      borderRadius: '9999px',
                      background: isWeightOverload ? 'var(--status-rose)' : 'var(--status-emerald)',
                      color: '#ffffff'
                    }}>
                      {isWeightOverload ? 'Overloaded' : 'Capacity Safe'}
                    </span>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    {cargoItems.map((item, idx) => (
                      <div key={idx} className="trip-form-grid-3" style={{ background: '#ffffff', padding: '12px', borderRadius: '8px', border: '1px solid var(--slate-200)' }}>
                        <div>
                          <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>Item Name</label>
                          <input
                            type="text"
                            value={item.productName}
                            onChange={(e) => {
                              const updated = [...cargoItems];
                              updated[idx].productName = e.target.value;
                              setCargoItems(updated);
                            }}
                            className="form-control"
                          />
                        </div>

                        <div>
                          <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>Quantity</label>
                          <input
                            type="number"
                            min="1"
                            value={item.plannedQty}
                            onChange={(e) => {
                              const updated = [...cargoItems];
                              updated[idx].plannedQty = parseInt(e.target.value, 10) || 0;
                              setCargoItems(updated);
                            }}
                            className="form-control"
                          />
                        </div>

                        <div>
                          <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-600)', marginBottom: '4px' }}>Unit Wt (kg)</label>
                          <input
                            type="number"
                            min="0.1"
                            step="0.5"
                            value={item.weightKg}
                            onChange={(e) => {
                              const updated = [...cargoItems];
                              updated[idx].weightKg = parseFloat(e.target.value) || 0;
                              setCargoItems(updated);
                            }}
                            className="form-control"
                          />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* STEP 6: SCHEDULE & DEPOT */}
              {currentStep === 6 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div>
                    <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                      Step 6: Dispatch Schedule &amp; Return Depot
                    </h3>
                    <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                      Set departure timeline, dispatch priority, and final return terminal.
                    </p>
                  </div>

                  <div className="trip-form-grid-2">
                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                        Planned Departure Date &amp; Time
                      </label>
                      <input
                        type="datetime-local"
                        value={plannedDeparture}
                        onChange={(e) => setPlannedDeparture(e.target.value)}
                        className="form-control"
                      />
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                        Dispatch Priority
                      </label>
                      <select
                        value={priority}
                        onChange={(e) => setPriority(e.target.value)}
                        className="form-control"
                      >
                        <option value="standard">Standard Route Delivery</option>
                        <option value="high">High Priority Express</option>
                        <option value="urgent">Urgent / Time-Critical</option>
                      </select>
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Final Return Depot Bay (Optional)
                    </label>
                    <select
                      value={returnDepotLocationId}
                      onChange={(e) => setReturnDepotLocationId(e.target.value)}
                      className="form-control"
                    >
                      <option value="">No Depot Return (Trip completes at last delivery)</option>
                      {locations.map(l => (
                        <option key={l.id} value={l.id}>
                          {l.name} - {l.address}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              )}

              {/* STEP 7: REVIEW & DISPATCH */}
              {currentStep === 7 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div>
                    <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
                      Step 7: Final Review &amp; Dispatch Confirmation
                    </h3>
                    <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                      Verify all waypoints, cargo manifests, and driver assignments before dispatching.
                    </p>
                  </div>

                  <div className="trip-form-grid-2">
                    <div style={{ background: 'var(--slate-50)', padding: '12px', borderRadius: '8px', border: '1px solid var(--slate-200)', fontSize: '12px' }}>
                      <div style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Driver &amp; Vehicle</div>
                      <div style={{ fontWeight: 800, color: 'var(--navy-800)', marginTop: '2px' }}>{selectedDriver?.name} ({selectedDriver?.phone})</div>
                      <div style={{ color: 'var(--slate-600)' }}>{selectedVehicle?.registrationNumber} - {selectedVehicle?.model}</div>
                    </div>

                    <div style={{ background: 'var(--slate-50)', padding: '12px', borderRadius: '8px', border: '1px solid var(--slate-200)', fontSize: '12px' }}>
                      <div style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Total Cargo Weight</div>
                      <div style={{ fontWeight: 800, color: 'var(--navy-800)', marginTop: '2px' }}>{totalCargoWeight} kg payload</div>
                      <div style={{ color: 'var(--slate-600)' }}>{cargoItems.reduce((acc, c) => acc + c.plannedQty, 0)} total units across {cargoItems.length} product lines</div>
                    </div>
                  </div>

                  <div style={{ border: '1px solid var(--slate-200)', borderRadius: '10px', overflow: 'hidden' }}>
                    <div style={{ background: 'var(--slate-100)', padding: '8px 12px', fontSize: '11px', fontWeight: 800, color: 'var(--slate-600)', textTransform: 'uppercase' }}>
                      Planned Waypoints ({1 + pickupStops.length + deliveryStops.length + (returnDepotLocationId ? 1 : 0)} Total Stops)
                    </div>
                    <div style={{ padding: '8px 12px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <div>1. Origin: <strong>{startLoc?.name}</strong> (Base Departure)</div>
                      {pickupStops.map((p, i) => {
                        const l = locations.find(loc => loc.id === p.locationId);
                        return <div key={i}>{2 + i}. Pickup: <strong>{l?.name || 'Warehouse'}</strong> ({p.cargoSummary})</div>;
                      })}
                      {deliveryStops.map((d, i) => {
                        const l = locations.find(loc => loc.id === d.locationId);
                        return <div key={i}>{2 + pickupStops.length + i}. Delivery: <strong>{l?.name || 'Customer'}</strong> ({d.recipientName})</div>;
                      })}
                      {returnDepotLocationId && (
                        <div>{2 + pickupStops.length + deliveryStops.length}. Depot Return: <strong>{locations.find(l => l.id === returnDepotLocationId)?.name || 'Depot'}</strong></div>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </>
          )}

        </div>

        {/* Modal Footer Controls */}
        <div className="trip-modal-footer">
          {dispatchMode === 'express' ? (
            /* Express Mode Footer: Simple Cancel + Big 1-Click Dispatch */
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
              <button
                type="button"
                onClick={onClose}
                className="btn btn-secondary"
              >
                Cancel
              </button>

              <button
                type="button"
                onClick={handleExpressDispatch}
                className="btn btn-primary"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '10px 24px',
                  fontWeight: 800,
                  fontSize: '13.5px',
                  background: 'linear-gradient(135deg, #0284c7 0%, #0d9488 100%)',
                  boxShadow: '0 4px 14px rgba(2, 132, 199, 0.3)'
                }}
              >
                <Zap size={16} />
                <span>Dispatch Trip Now</span>
              </button>
            </div>
          ) : (
            /* Advanced Mode Footer: Previous, Next, Confirm */
            <>
              {currentStep > 1 ? (
                <button
                  type="button"
                  onClick={handlePrevStep}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <ArrowLeft size={14} />
                  <span>Previous Step</span>
                </button>
              ) : (
                <button
                  type="button"
                  onClick={onClose}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
              )}

              {currentStep < 7 ? (
                <button
                  type="button"
                  onClick={handleNextStep}
                  className="btn btn-primary"
                  style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <span>Next Step</span>
                  <ArrowRight size={14} />
                </button>
              ) : (
                <button
                  type="button"
                  onClick={handleFinalDispatch}
                  className="btn btn-primary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 20px', fontWeight: 800 }}
                >
                  <Check size={16} />
                  <span>Confirm &amp; Dispatch Trip</span>
                </button>
              )}
            </>
          )}
        </div>

      </div>
    </div>
  );
}
