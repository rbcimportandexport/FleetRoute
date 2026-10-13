// client/src/utils/cloudFallbackData.js
// Cloud Standalone Fallback Store for Vercel/Static Environments
// Enables full interactive demo capabilities without an external backend

export const cloudFallbackData = {
  users: [
    {
      id: "USR-ADMIN-100",
      email: "admin@gmail.com",
      phone: "+919820011223",
      name: "System Administrator",
      role: "admin",
      status: "active"
    },
    {
      id: "USR-DRV-101",
      email: "rajeshsharma.drv-101@fleetroute.com",
      phone: "+91 99999 11111",
      name: "Rajesh Sharma",
      role: "driver",
      driverId: "DRV-101",
      status: "active"
    }
  ],

  drivers: [
    {
      id: "DRV-101",
      name: "Rajesh Sharma",
      phone: "+91 98210 44821",
      alternatePhone: "+91 98100 23456",
      avatar: "https://images.unsplash.com/photo-1544717305-2782549b5136?w=150&auto=format&fit=crop&q=80",
      licenseNumber: "DL-04-2015-098234",
      licenseExpiry: "2030-08-15",
      assignedVehicleId: "VEH-201",
      availability: "ON_DUTY",
      emergencyContact: "Sunita Sharma (+91 98210 11223)",
      safetyScore: 92,
      activeTripId: "TRIP-DEMO-01",
      completedTripsCount: 142
    },
    {
      id: "DRV-102",
      name: "Sanjay Patil",
      phone: "+91 98200 99112",
      alternatePhone: "+91 98200 44556",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80",
      licenseNumber: "MH-04-2017-004512",
      licenseExpiry: "2029-11-20",
      assignedVehicleId: "VEH-202",
      availability: "ON_DUTY",
      emergencyContact: "Anita Patil (+91 98200 77889)",
      safetyScore: 88,
      activeTripId: "TRIP-PARTIAL-02",
      completedTripsCount: 98
    }
  ],

  vehicles: [
    {
      id: "VEH-201",
      registrationNumber: "DL-1L-AA-2415",
      type: "TATA_407_TRUCK",
      model: "Tata 407 LPT Heavy Duty",
      capacityKg: 3500,
      currentOdometerKm: 42150,
      fuelPercentage: 78,
      status: "ACTIVE",
      assignedDriverId: "DRV-101",
      lastMaintenanceDate: "2026-09-10"
    },
    {
      id: "VEH-202",
      registrationNumber: "MH-04-AB-9812",
      type: "MAHINDRA_BOLERO_MAXI",
      model: "Mahindra Bolero Maxi Truck Plus",
      capacityKg: 1700,
      currentOdometerKm: 28430,
      fuelPercentage: 62,
      status: "ACTIVE",
      assignedDriverId: "DRV-102",
      lastMaintenanceDate: "2026-08-25"
    }
  ],

  locations: [
    {
      id: "LOC-HOME",
      name: "Driver Home Base & Depot",
      type: "home_base",
      address: "Plot 42, Sector 49, Sohna Road, Gurugram",
      lat: 28.4124,
      lng: 77.0421,
      contactPerson: "Rajesh Sharma",
      contactNumber: "+91 98210 44821",
      landmark: "Near Vatika Business Park",
      arrivalRadiusMeters: 150,
      instructions: "Inspect odometer and vehicle walkaround before departure.",
      status: "active"
    },
    {
      id: "LOC-WH-OKHLA",
      name: "Central Logistics Warehouse Hub (Bay 4)",
      type: "warehouse",
      address: "Bay #4, Okhla Industrial Area Phase-III, New Delhi",
      lat: 28.5355,
      lng: 77.2684,
      contactPerson: "Mahesh Verma (Supervisor)",
      contactNumber: "+91 98111 22334",
      landmark: "Opposite C-DOT Complex Gate 2",
      arrivalRadiusMeters: 200,
      instructions: "Show dispatch gate-pass at entrance. Check seal lock.",
      status: "active"
    },
    {
      id: "LOC-CUST-CP",
      name: "Connaught Place Retail Plaza (Customer A)",
      type: "customer",
      address: "Block B, Inner Circle, Connaught Place, New Delhi",
      lat: 28.6328,
      lng: 77.2197,
      contactPerson: "Ramesh Gupta (Store Manager)",
      contactNumber: "+91 98101 55667",
      landmark: "Near Rajiv Chowk Metro Gate 3",
      arrivalRadiusMeters: 100,
      instructions: "Deliver to 2nd floor retail showroom. Obtain customer signature.",
      status: "active"
    },
    {
      id: "LOC-CUST-BK",
      name: "Barakhamba Corporate Towers (Customer B)",
      type: "customer",
      address: "14 Barakhamba Road, Connaught Place Outer, New Delhi",
      lat: 28.6275,
      lng: 77.2285,
      contactPerson: "Priya Sundaram (Admin Ops)",
      contactNumber: "+91 98188 99001",
      landmark: "Next to Statesman House",
      arrivalRadiusMeters: 120,
      instructions: "Service elevator behind Tower B. Signature mandatory on invoice.",
      status: "active"
    }
  ],

  products: [
    {
      id: "PRD-CHR-01",
      name: "Ergonomic High-Back Mesh Office Chair",
      category: "OFFICE_FURNITURE",
      sku: "FURN-CHR-001",
      unitWeightKg: 18.5,
      description: "Breathable mesh back with lumbar support.",
      status: "active"
    },
    {
      id: "PRD-CHR-02",
      name: "Luxury Zero-Gravity Shiatsu Massage Recliner",
      category: "LUXURY_APPLIANCE",
      sku: "APPL-MSG-002",
      unitWeightKg: 85.0,
      description: "Full body zero gravity shiatsu heating massage chair.",
      status: "active"
    }
  ],

  trips: [
    {
      id: "TRIP-DEMO-01",
      title: "Delhi-NCR Multi-Customer Furniture & Appliance Run",
      driverId: "DRV-101",
      vehicleId: "VEH-201",
      status: "IN_TRANSIT",
      currentStage: "DELIVERY_STOP_A",
      startedAt: new Date(Date.now() - 3600000).toISOString(),
      plannedCompletion: new Date(Date.now() + 7200000).toISOString(),
      totalDistanceKm: 68.4,
      distanceCoveredKm: 34.2,
      currentSpeedKmH: 42,
      speedLimitKmH: 50,
      seatbeltFastened: true,
      dispatcherNotes: "High-value furniture trip. Handle massage chairs with extreme care.",
      priority: "HIGH",
      routeStops: [
        {
          id: "STOP-01",
          stopNumber: 1,
          type: "ORIGIN_HOME",
          locationId: "LOC-HOME",
          name: "Driver Home Base & Depot",
          address: "Plot 42, Sector 49, Sohna Road, Gurugram",
          lat: 28.4124,
          lng: 77.0421,
          scheduledTime: "07:30 AM",
          actualTime: "07:30 AM",
          status: "COMPLETED",
          purpose: "Departure & Vehicle Pre-Trip Checks",
          dwellMinutes: 10
        },
        {
          id: "STOP-02",
          stopNumber: 2,
          type: "CARGO_PICKUP",
          locationId: "LOC-WH-OKHLA",
          name: "Central Logistics Warehouse Hub (Bay 4)",
          address: "Bay #4, Okhla Industrial Area Phase-III, New Delhi",
          lat: 28.5355,
          lng: 77.2684,
          scheduledTime: "08:15 AM",
          actualTime: "08:20 AM",
          status: "COMPLETED",
          purpose: "Warehouse Loading (12 Office Chairs + 3 Massage Chairs)",
          dwellMinutes: 25
        },
        {
          id: "STOP-03",
          stopNumber: 3,
          type: "DELIVERY_STOP_A",
          locationId: "LOC-CUST-CP",
          name: "Connaught Place Retail Plaza (Customer A)",
          address: "Block B, Inner Circle, Connaught Place, New Delhi",
          lat: 28.6328,
          lng: 77.2197,
          scheduledTime: "09:45 AM",
          actualTime: "10:02 AM",
          status: "CURRENT",
          purpose: "Unload 5 Office Chairs to Ramesh Gupta",
          dwellMinutes: 15
        },
        {
          id: "STOP-04",
          stopNumber: 4,
          type: "DELIVERY_STOP_B",
          locationId: "LOC-CUST-BK",
          name: "Barakhamba Corporate Towers (Customer B)",
          address: "14 Barakhamba Road, Connaught Place Outer, New Delhi",
          lat: 28.6275,
          lng: 77.2285,
          scheduledTime: "10:30 AM",
          status: "PENDING",
          purpose: "Deliver 7 Office Chairs & 2 Massage Chairs",
          dwellMinutes: 20
        }
      ]
    }
  ],

  safetyEvents: [],
  deliveryProofs: [],
  settings: {
    speedThresholdKmH: 80,
    minSustainedSeconds: 15,
    defaultArrivalRadiusMeters: 150,
    timezone: "Asia/Kolkata",
    utcStandard: "ISO-8601"
  }
};
