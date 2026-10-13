// server/seedData.js

const seedDrivers = [
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
  },
  {
    id: "DRV-103",
    name: "Vikramjit Singh",
    phone: "+91 98140 33221",
    alternatePhone: "+91 98140 11998",
    avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "PB-10-2018-883344",
    licenseExpiry: "2031-04-12",
    assignedVehicleId: "VEH-203",
    availability: "ON_DUTY",
    emergencyContact: "Harpreet Kaur (+91 98140 66778)",
    safetyScore: 95,
    activeTripId: "TRIP-MUM-03",
    completedTripsCount: 210
  },
  {
    id: "DRV-104",
    name: "Anil Deshmukh",
    phone: "+91 98230 55667",
    alternatePhone: "+91 98230 11223",
    avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "MH-12-2016-112299",
    licenseExpiry: "2028-09-30",
    assignedVehicleId: "VEH-204",
    availability: "AVAILABLE",
    emergencyContact: "Kavita Deshmukh (+91 98230 99887)",
    safetyScore: 90,
    activeTripId: null,
    completedTripsCount: 84
  },
  {
    id: "DRV-105",
    name: "Manoj Kumar Yadav",
    phone: "+91 98180 77889",
    alternatePhone: "+91 98180 33445",
    avatar: "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "UP-16-2019-445566",
    licenseExpiry: "2032-02-18",
    assignedVehicleId: "VEH-205",
    availability: "ON_DUTY",
    emergencyContact: "Geeta Yadav (+91 98180 22110)",
    safetyScore: 84,
    activeTripId: "TRIP-BLR-04",
    completedTripsCount: 115
  },
  {
    id: "DRV-106",
    name: "Karthik Raman",
    phone: "+91 98400 11223",
    alternatePhone: "+91 98400 44332",
    avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "TN-01-2020-998877",
    licenseExpiry: "2033-05-22",
    assignedVehicleId: "VEH-206",
    availability: "AVAILABLE",
    emergencyContact: "Deepa Raman (+91 98400 88776)",
    safetyScore: 97,
    activeTripId: null,
    completedTripsCount: 65
  },
  {
    id: "DRV-107",
    name: "Arjun Verma",
    phone: "+91 98110 99887",
    alternatePhone: "+91 98110 55443",
    avatar: "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "DL-01-2021-332211",
    licenseExpiry: "2034-01-10",
    assignedVehicleId: "VEH-207",
    availability: "OFF_DUTY",
    emergencyContact: "Pooja Verma (+91 98110 22334)",
    safetyScore: 89,
    activeTripId: null,
    completedTripsCount: 78
  },
  {
    id: "DRV-108",
    name: "Bhupinder Gill",
    phone: "+91 98150 44332",
    alternatePhone: "+91 98150 88776",
    avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80",
    licenseNumber: "PB-65-2014-667788",
    licenseExpiry: "2027-10-05",
    assignedVehicleId: "VEH-208",
    availability: "AVAILABLE",
    emergencyContact: "Simran Gill (+91 98150 11990)",
    safetyScore: 91,
    activeTripId: null,
    completedTripsCount: 160
  }
];

const seedVehicles = [
  {
    id: "VEH-201",
    registrationNumber: "HR-26-EC-9014",
    vehicleType: "TRUCK",
    model: "Tata 407 LPT Heavy Cargo",
    maxCargoWeightKg: 2800,
    volumeCapacityM3: 14.5,
    fuelType: "DIESEL",
    odometerKm: 64280,
    assignedDriverId: "DRV-101",
    availability: "ASSIGNED",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-202",
    registrationNumber: "MH-04-AK-5521",
    vehicleType: "PICKUP",
    model: "Mahindra Bolero Maxi Truck Plus",
    maxCargoWeightKg: 1700,
    volumeCapacityM3: 9.2,
    fuelType: "DIESEL",
    odometerKm: 48120,
    assignedDriverId: "DRV-102",
    availability: "ASSIGNED",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-203",
    registrationNumber: "PB-10-CT-5532",
    vehicleType: "MINI_TRUCK",
    model: "Tata Ace Gold (Chhota Hathi)",
    maxCargoWeightKg: 950,
    volumeCapacityM3: 6.0,
    fuelType: "CNG",
    odometerKm: 32450,
    assignedDriverId: "DRV-103",
    availability: "ASSIGNED",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-204",
    registrationNumber: "MH-12-RN-8809",
    vehicleType: "VAN",
    model: "Force Delivery Van High Roof",
    maxCargoWeightKg: 1500,
    volumeCapacityM3: 11.0,
    fuelType: "DIESEL",
    odometerKm: 55400,
    assignedDriverId: "DRV-104",
    availability: "AVAILABLE",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-205",
    registrationNumber: "UP-16-BZ-3319",
    vehicleType: "TRUCK",
    model: "Eicher Pro 2049 14ft Deck",
    maxCargoWeightKg: 3200,
    volumeCapacityM3: 16.8,
    fuelType: "DIESEL",
    odometerKm: 78900,
    assignedDriverId: "DRV-105",
    availability: "ASSIGNED",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-206",
    registrationNumber: "TN-01-EF-4420",
    vehicleType: "PICKUP",
    model: "Ashok Leyland Dost+",
    maxCargoWeightKg: 1500,
    volumeCapacityM3: 8.5,
    fuelType: "DIESEL",
    odometerKm: 29800,
    assignedDriverId: "DRV-106",
    availability: "AVAILABLE",
    maintenanceStatus: "GOOD"
  },
  {
    id: "VEH-207",
    registrationNumber: "DL-01-AB-1234",
    vehicleType: "MINI_TRUCK",
    model: "Mahindra Supro Maxi Truck",
    maxCargoWeightKg: 1050,
    volumeCapacityM3: 6.5,
    fuelType: "DIESEL",
    odometerKm: 41200,
    assignedDriverId: null,
    availability: "AVAILABLE",
    maintenanceStatus: "SCHEDULED_SERVICE"
  },
  {
    id: "VEH-208",
    registrationNumber: "PB-65-XY-7788",
    vehicleType: "TRUCK",
    model: "Tata 709 LPT 17ft Container",
    maxCargoWeightKg: 4500,
    volumeCapacityM3: 22.0,
    fuelType: "DIESEL",
    odometerKm: 92400,
    assignedDriverId: null,
    availability: "AVAILABLE",
    maintenanceStatus: "GOOD"
  }
];

const seedProducts = [
  {
    id: "PRD-01",
    name: "High-Back Ergonomic Office Chair",
    category: "OFFICE_CHAIRS",
    description: "Mesh breathable swivel chair with lumbar support and nylon rollers",
    defaultWeightKg: 14.5,
    defaultVolumeM3: 0.25,
    unit: "units",
    fragile: false
  },
  {
    id: "PRD-02",
    name: "Luxury 4D Zero-Gravity Massage Chair",
    category: "MASSAGE_CHAIRS",
    description: "Multi-point acoustic robotic massage recliner with body scan sensors",
    defaultWeightKg: 115.0,
    defaultVolumeM3: 1.45,
    unit: "units",
    fragile: true
  },
  {
    id: "PRD-03",
    name: "Motorized Power Recliner Chair",
    category: "RECLINER_CHAIRS",
    description: "Electric dual-motor leatherette lounge recliner with remote",
    defaultWeightKg: 48.0,
    defaultVolumeM3: 0.85,
    unit: "units",
    fragile: true
  },
  {
    id: "PRD-04",
    name: "Modular Workstation Furniture Carton",
    category: "FURNITURE_CARTONS",
    description: "Flat-pack modular MDF office desk set with assembly hardware",
    defaultWeightKg: 35.0,
    defaultVolumeM3: 0.40,
    unit: "cartons",
    fragile: false
  },
  {
    id: "PRD-05",
    name: "Industrial Hardware Fastener Box",
    category: "HARDWARE_BOXES",
    description: "Galvanized zinc steel bolts, brackets, and structural anchors",
    defaultWeightKg: 28.0,
    defaultVolumeM3: 0.08,
    unit: "boxes",
    fragile: false
  },
  {
    id: "PRD-06",
    name: "Hydraulic Hand Pallet Truck",
    category: "MATERIAL_HANDLING",
    description: "Manual hydraulic forklift hand trolley 2.5 ton rating with polyurethane wheels",
    defaultWeightKg: 72.0,
    defaultVolumeM3: 0.65,
    unit: "units",
    fragile: false
  },
  {
    id: "PRD-07",
    name: "Smart Hoverboard Mobility Chair",
    category: "MOBILITY_DEVICES",
    description: "Electric omni-directional power wheelchair with 36V lithium battery",
    defaultWeightKg: 46.0,
    defaultVolumeM3: 0.70,
    unit: "units",
    fragile: true
  },
  {
    id: "PRD-08",
    name: "Medical Diagnostic Equipment Box",
    category: "GENERAL_GOODS",
    description: "Calibrated optical telemetry sensors and monitoring display packs",
    defaultWeightKg: 22.0,
    defaultVolumeM3: 0.35,
    unit: "crates",
    fragile: true
  },
  {
    id: "PRD-09",
    name: "Commercial Pallet Jack Roller Set",
    category: "HARDWARE_BOXES",
    description: "Heavy duty steel bearing replacements for warehouse dock trolleys",
    defaultWeightKg: 18.0,
    defaultVolumeM3: 0.05,
    unit: "sets",
    fragile: false
  },
  {
    id: "PRD-10",
    name: "General Retail Merchandise Crate",
    category: "GENERAL_GOODS",
    description: "Assorted consumer electronics accessories and display merchandise",
    defaultWeightKg: 25.0,
    defaultVolumeM3: 0.30,
    unit: "crates",
    fragile: false
  }
];

const seedUsers = [
  {
    id: "USR-ADMIN-01",
    email: "admin@fleetroute.com",
    phone: "+919800000000",
    name: "Central Dispatch Control",
    role: "admin",
    status: "active",
    passwordHash: "$2b$10$NKSeEe26a838va.s7LutEOsTDmzO54QxlVBQw1leatHvM2nXsraq.", // AdminPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-101",
    email: "rajesh@fleetroute.com",
    phone: "+919821044821",
    name: "Rajesh Sharma",
    role: "driver",
    driverId: "DRV-101",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-102",
    email: "sanjay@fleetroute.com",
    phone: "+919820099112",
    name: "Sanjay Patil",
    role: "driver",
    driverId: "DRV-102",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-103",
    email: "vikram@fleetroute.com",
    phone: "+919814033221",
    name: "Vikramjit Singh",
    role: "driver",
    driverId: "DRV-103",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-104",
    email: "anil@fleetroute.com",
    phone: "+919823055667",
    name: "Anil Deshmukh",
    role: "driver",
    driverId: "DRV-104",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-105",
    email: "manoj@fleetroute.com",
    phone: "+919818077889",
    name: "Manoj Kumar Yadav",
    role: "driver",
    driverId: "DRV-105",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-106",
    email: "karthik@fleetroute.com",
    phone: "+919840011223",
    name: "Karthik Raman",
    role: "driver",
    driverId: "DRV-106",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-107",
    email: "arjun@fleetroute.com",
    phone: "+919811099887",
    name: "Arjun Verma",
    role: "driver",
    driverId: "DRV-107",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  },
  {
    id: "USR-DRV-108",
    email: "bhupinder@fleetroute.com",
    phone: "+919815044332",
    name: "Bhupinder Gill",
    role: "driver",
    driverId: "DRV-108",
    status: "active",
    passwordHash: "$2b$10$//cQEPw94ksfXI/R8zjytOMg3NUuvBaLes5QRs4dIMWSTi/EG.7ty", // DriverPassword123!
    createdAt: "2026-10-12T00:00:00Z"
  }
];

const seedLocations = [
  {
    id: "LOC-HOME",
    name: "Driver Home Base & Depot",
    type: "driver_base",
    address: "Plot 42, Sector 49, Sohna Road, Gurugram, Haryana",
    lat: 28.4124,
    lng: 77.0421,
    contactPerson: "Depot Supervisor",
    contactNumber: "+91 98210 00111",
    landmark: "Near Vatika Business Park",
    arrivalRadiusMeters: 150,
    instructions: "Pre-trip vehicle safety check and odometer log.",
    status: "active"
  },
  {
    id: "LOC-WH-OKHLA",
    name: "Central Logistics Warehouse Hub (Bay 4)",
    type: "warehouse",
    address: "Bay #4, Okhla Industrial Area Phase-III, New Delhi",
    lat: 28.5355,
    lng: 77.2684,
    contactPerson: "Mahesh Rawat (Hub Mgr)",
    contactNumber: "+91 98111 22334",
    landmark: "Behind Modi Flour Mills",
    arrivalRadiusMeters: 200,
    instructions: "Back vehicle into Bay 4. Heavy hydraulic lift required.",
    status: "active"
  },
  {
    id: "LOC-CUST-CP",
    name: "Connaught Place Retail Plaza (Customer A)",
    type: "customer",
    address: "Block B, Inner Circle, Connaught Place, New Delhi",
    lat: 28.6328,
    lng: 77.2197,
    contactPerson: "Ramesh Gupta (Store Lead)",
    contactNumber: "+91 98111 44556",
    landmark: "Near Rajiv Chowk Metro Gate 2",
    arrivalRadiusMeters: 100,
    instructions: "Delivery access via rear service alleyway before 11:00 AM.",
    status: "active"
  },
  {
    id: "LOC-CUST-BK",
    name: "Barakhamba Corporate Towers (Customer B)",
    type: "customer",
    address: "14 Barakhamba Road, Connaught Place Outer, New Delhi",
    lat: 28.6275,
    lng: 77.2285,
    contactPerson: "Kavita Sethi (Admin Head)",
    contactNumber: "+91 98111 66778",
    landmark: "Opposite Statesman House",
    arrivalRadiusMeters: 120,
    instructions: "Security gate pass at Tower 2 entrance.",
    status: "active"
  },
  {
    id: "LOC-CUST-NOIDA",
    name: "Horizon Technopark Tower 3 (Customer C)",
    type: "customer",
    address: "Plot 12, Sector 62, Noida, Uttar Pradesh",
    lat: 28.6258,
    lng: 77.3688,
    contactPerson: "Vikram Malhotra (Facility Lead)",
    contactNumber: "+91 98222 33445",
    landmark: "Near Fortis Hospital Junction",
    arrivalRadiusMeters: 150,
    instructions: "Freight elevator B available on ground floor.",
    status: "active"
  },
  {
    id: "LOC-DEPOT-DELHI",
    name: "Central Depot & Return Bay",
    type: "depot",
    address: "NH-48 Service Lane, Mahipalpur Transport Bay, New Delhi",
    lat: 28.5441,
    lng: 77.1215,
    contactPerson: "Surender Pal",
    contactNumber: "+91 98100 88990",
    landmark: "Near IGI Airport T3 Cargo Terminal",
    arrivalRadiusMeters: 250,
    instructions: "Unload damaged goods and register return receipt.",
    status: "active"
  }
];

// Required Specific Demo Trip (TRIP-DEMO-01)
// Driving: 120m, Loading: 25m, Unloading: 45m, Traffic: 20m, Refuel: 10m, Puncture: 30m. Total = 250m.
const demoStartTime = new Date("2026-10-12T07:30:00Z"); // 07:30 UTC
const demoEndTime = new Date(demoStartTime.getTime() + 250 * 60 * 1000); // 11:40 UTC (250 mins)

const seedTrips = [
  {
    id: "TRIP-DEMO-01",
    title: "Delhi-NCR Multi-Customer Furniture & Appliance Run",
    driverId: "DRV-101",
    vehicleId: "VEH-201",
    status: "IN_TRANSIT",
    currentStage: "DELIVERY_STOP_A",
    startedAt: demoStartTime.toISOString(),
    plannedCompletion: demoEndTime.toISOString(),
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
        purpose: "Warehouse Loading (12 Office Chairs + 3 Massage Chairs = 15 Units)",
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
        actualTime: "Pending",
        status: "PENDING",
        purpose: "Unload 7 Office Chairs to Kavita Sethi",
        dwellMinutes: 15
      },
      {
        id: "STOP-05",
        stopNumber: 5,
        type: "DELIVERY_STOP_C",
        locationId: "LOC-CUST-NOIDA",
        name: "Horizon Technopark Tower 3 (Customer C)",
        address: "Plot 12, Sector 62, Noida, Uttar Pradesh",
        lat: 28.6258,
        lng: 77.3688,
        scheduledTime: "11:20 AM",
        actualTime: "Pending",
        status: "PENDING",
        purpose: "Unload 3 Massage Chairs to Vikram Malhotra",
        dwellMinutes: 15
      },
      {
        id: "STOP-06",
        stopNumber: 6,
        type: "DEPOT_RETURN",
        locationId: "LOC-DEPOT-DELHI",
        name: "Central Depot & Return Bay",
        address: "NH-48 Service Lane, Mahipalpur, New Delhi",
        lat: 28.5441,
        lng: 77.1215,
        scheduledTime: "11:40 AM",
        actualTime: "Pending",
        status: "PENDING",
        purpose: "Final Trip Closure & Vehicle Post-Trip Inspection",
        dwellMinutes: 10
      }
    ],
    cargoLines: [
      {
        id: "CRG-01",
        productId: "PRD-01",
        name: "High-Back Ergonomic Office Chair",
        category: "OFFICE_CHAIRS",
        quantityPlanned: 12,
        quantityLoaded: 12,
        quantityDelivered: 0,
        quantityOnboard: 12,
        quantityDamaged: 0,
        quantityReturned: 0,
        pickupStopId: "STOP-02",
        destinationStopId: "STOP-03", // 5 for Stop A, 7 for Stop B
        allocations: [
          { stopId: "STOP-03", customer: "Customer A (Connaught Place)", quantity: 5 },
          { stopId: "STOP-04", customer: "Customer B (Barakhamba)", quantity: 7 }
        ],
        weightKgTotal: 174,
        unit: "units",
        fragile: false
      },
      {
        id: "CRG-02",
        productId: "PRD-02",
        name: "Luxury 4D Zero-Gravity Massage Chair",
        category: "MASSAGE_CHAIRS",
        quantityPlanned: 3,
        quantityLoaded: 3,
        quantityDelivered: 0,
        quantityOnboard: 3,
        quantityDamaged: 0,
        quantityReturned: 0,
        pickupStopId: "STOP-02",
        destinationStopId: "STOP-05",
        allocations: [
          { stopId: "STOP-05", customer: "Customer C (Noida Technopark)", quantity: 3 }
        ],
        weightKgTotal: 345,
        unit: "units",
        fragile: true
      }
    ],
    // Time breakdown mathematically constructed: 250 minutes total
    activityTimeline: [
      {
        id: "ACT-01",
        category: "DRIVING",
        title: "Departure from Home Depot to Warehouse",
        startMinutes: 0,
        durationMinutes: 45,
        location: "Gurugram to Okhla Industrial Area",
        notes: "Clear traffic on NH-48 corridor."
      },
      {
        id: "ACT-02",
        category: "LOADING",
        title: "Warehouse Dock Cargo Pallet Loading",
        startMinutes: 45,
        durationMinutes: 25,
        location: "Okhla Bay 4 Logistics Hub",
        notes: "Loaded 12 office chairs and 3 luxury massage chairs (15 units total)."
      },
      {
        id: "ACT-03",
        category: "REFUELING",
        title: "Diesel Refueling at Indian Oil Pump",
        startMinutes: 70,
        durationMinutes: 10,
        location: "Indian Oil Station, Mathura Road",
        notes: "Filled 45 liters diesel. INR 4,185 cost."
      },
      {
        id: "ACT-04",
        category: "TRAFFIC_DELAY",
        title: "Heavy Traffic Choke-Point Snarl",
        startMinutes: 80,
        durationMinutes: 20,
        location: "Sarai Kale Khan Ring Road Bottleneck",
        notes: "Rush hour congestion delayed progress."
      },
      {
        id: "ACT-05",
        category: "PUNCTURE_REPAIR",
        title: "Roadside Tubeless Tyre Puncture Vulcanization",
        startMinutes: 100,
        durationMinutes: 30,
        location: "Bhairon Marg Service Bay",
        notes: "Rear tyre lost pressure; repaired by roadside mobile mechanic. INR 350 cost."
      },
      {
        id: "ACT-06",
        category: "DRIVING",
        title: "In Transit to Connaught Place Plaza",
        startMinutes: 130,
        durationMinutes: 35,
        location: "India Gate & Janpath Boulevard",
        notes: "Steady driving."
      },
      {
        id: "ACT-07",
        category: "UNLOADING",
        title: "Dock Unloading at Stop A (Connaught Place)",
        startMinutes: 165,
        durationMinutes: 15,
        location: "Block B, Inner Circle, Connaught Place",
        notes: "Unloaded 5 office chairs for Ramesh Gupta."
      },
      {
        id: "ACT-08",
        category: "DRIVING",
        title: "In Transit to Barakhamba Towers (Stop B)",
        startMinutes: 180,
        durationMinutes: 15,
        location: "Outer Circle to Barakhamba Road",
        notes: "Short urban leg."
      },
      {
        id: "ACT-09",
        category: "UNLOADING",
        title: "Dock Unloading at Stop B (Barakhamba)",
        startMinutes: 195,
        durationMinutes: 15,
        location: "Statesman House Delivery Bay",
        notes: "Unloaded 7 office chairs for Kavita Sethi."
      },
      {
        id: "ACT-10",
        category: "DRIVING",
        title: "Highway Transit to Noida Sector 62 (Stop C)",
        startMinutes: 210,
        durationMinutes: 25,
        location: "DND Flyway & Noida Link Expressway",
        notes: "Expressway driving."
      },
      {
        id: "ACT-11",
        category: "UNLOADING",
        title: "Final Unloading at Stop C (Horizon Technopark)",
        startMinutes: 235,
        durationMinutes: 15,
        location: "Horizon Tower 3 Freight Dock",
        notes: "Unloaded 3 massage chairs for Vikram Malhotra. Zero units remaining onboard."
      }
    ]
  },
  // Trip 2: Partial delivery with damaged cargo returned to depot
  {
    id: "TRIP-PARTIAL-02",
    title: "Mumbai Western Corridor Multi-Drop & Damage Return Case",
    driverId: "DRV-102",
    vehicleId: "VEH-202",
    status: "IN_TRANSIT",
    currentStage: "RETURN_TO_DEPOT",
    startedAt: new Date(Date.now() - 3 * 3600 * 1000).toISOString(),
    plannedCompletion: new Date(Date.now() + 1 * 3600 * 1000).toISOString(),
    totalDistanceKm: 52.0,
    distanceCoveredKm: 42.0,
    currentSpeedKmH: 38,
    speedLimitKmH: 50,
    seatbeltFastened: true,
    dispatcherNotes: "Client reported damaged recliner box during dock inspection. Item returning to Bhiwandi depot.",
    priority: "MEDIUM",
    routeStops: [
      {
        id: "ST-M01",
        stopNumber: 1,
        type: "ORIGIN_HOME",
        name: "Thane Driver Garage",
        address: "Ghodbunder Road, Thane",
        lat: 19.2183,
        lng: 72.9781,
        status: "COMPLETED",
        purpose: "Departure"
      },
      {
        id: "ST-M02",
        stopNumber: 2,
        type: "CARGO_PICKUP",
        name: "Bhiwandi Central Logistics Hub",
        address: "Arihant Complex, Bhiwandi",
        lat: 19.2967,
        lng: 73.0631,
        status: "COMPLETED",
        purpose: "Loaded 4 Power Recliners + 2 Hardware Boxes"
      },
      {
        id: "ST-M03",
        stopNumber: 3,
        type: "DELIVERY_STOP_A",
        name: "BKC Finance Tower (Stop A)",
        address: "G Block, Bandra Kurla Complex",
        lat: 19.0657,
        lng: 72.8687,
        status: "COMPLETED",
        purpose: "Delivered 2 Recliners. 1 Recliner Damaged in transit (Rejected by Client).",
        notes: "Client signed POD for 2 delivered, rejected 1 damaged unit."
      },
      {
        id: "ST-M04",
        stopNumber: 4,
        type: "DELIVERY_STOP_B",
        name: "Andheri MIDC Plaza (Stop B)",
        address: "Road No 16, MIDC, Andheri East",
        lat: 19.1197,
        lng: 72.8719,
        status: "COMPLETED",
        purpose: "Delivered 2 Hardware Boxes successfully."
      },
      {
        id: "ST-M05",
        stopNumber: 5,
        type: "DEPOT_RETURN",
        name: "Bhiwandi Depot Return Bay",
        address: "Bhiwandi Hub Return Gate",
        lat: 19.2967,
        lng: 73.0631,
        status: "CURRENT",
        purpose: "Returning 1 Damaged Recliner + 1 Excess Recliner to Depot"
      }
    ],
    cargoLines: [
      {
        id: "CRG-M01",
        productId: "PRD-03",
        name: "Motorized Power Recliner Chair",
        category: "RECLINER_CHAIRS",
        quantityPlanned: 4,
        quantityLoaded: 4,
        quantityDelivered: 2,
        quantityDamaged: 1,
        quantityReturned: 2, // 1 damaged + 1 unaccepted
        quantityOnboard: 2,
        unit: "units",
        fragile: true
      }
    ]
  }
];

module.exports = {
  seedUsers,
  seedDrivers,
  seedVehicles,
  seedProducts,
  seedLocations,
  seedTrips
};
