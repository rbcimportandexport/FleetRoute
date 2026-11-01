import reportlab
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

pdf_path = r'd:\TRANSPORT 1\DRIVER_DATA_GUIDE.pdf'
doc = SimpleDocTemplate(
    pdf_path,
    pagesize=letter,
    leftMargin=36,
    rightMargin=36,
    topMargin=36,
    bottomMargin=36
)

styles = getSampleStyleSheet()

primary_color = colors.HexColor('#1E3A8A')
secondary_color = colors.HexColor('#0D9488')
dark_neutral = colors.HexColor('#1F2937')
light_bg = colors.HexColor('#F8FAFC')

title_style = ParagraphStyle(
    'DocTitle',
    parent=styles['Heading1'],
    fontName='Helvetica-Bold',
    fontSize=20,
    leading=24,
    textColor=primary_color,
    alignment=1,
    spaceAfter=6
)

subtitle_style = ParagraphStyle(
    'DocSubTitle',
    parent=styles['Normal'],
    fontName='Helvetica',
    fontSize=10.5,
    leading=14,
    textColor=colors.HexColor('#4B5563'),
    alignment=1,
    spaceAfter=12
)

section_heading = ParagraphStyle(
    'SecHead',
    parent=styles['Heading2'],
    fontName='Helvetica-Bold',
    fontSize=12,
    leading=16,
    textColor=primary_color,
    spaceBefore=12,
    spaceAfter=6,
    keepWithNext=True
)

sub_heading = ParagraphStyle(
    'SubHead',
    parent=styles['Heading3'],
    fontName='Helvetica-Bold',
    fontSize=9.5,
    leading=13,
    textColor=secondary_color,
    spaceBefore=7,
    spaceAfter=3,
    keepWithNext=True
)

body = ParagraphStyle(
    'Body',
    parent=styles['Normal'],
    fontName='Helvetica',
    fontSize=8.5,
    leading=12,
    textColor=dark_neutral,
    spaceAfter=4
)

table_header = ParagraphStyle(
    'TH',
    parent=styles['Normal'],
    fontName='Helvetica-Bold',
    fontSize=8,
    leading=10,
    textColor=colors.white,
    alignment=1
)

table_cell = ParagraphStyle(
    'TC',
    parent=styles['Normal'],
    fontName='Helvetica',
    fontSize=7.5,
    leading=10.5,
    textColor=dark_neutral
)

table_cell_bold = ParagraphStyle(
    'TCB',
    parent=table_cell,
    fontName='Helvetica-Bold'
)

table_cell_center = ParagraphStyle(
    'TCC',
    parent=table_cell,
    alignment=1
)

story = []

# Title Banner
story.append(Paragraph('TRANSPORT ONE - COMPLETE DRIVER DATA & FLEET TRACKING MANUAL', title_style))
story.append(Paragraph('Official Enterprise Specification & System Data Guide | Cloud Sync (Web & Mobile APK)', subtitle_style))
story.append(HRFlowable(width='100%', thickness=1.5, color=primary_color, spaceAfter=12))

# Section 1: Fleet Roster Overview
story.append(Paragraph('1. REGISTERED FLEET DRIVERS & VEHICLE MAPPING', section_heading))
story.append(Paragraph('The Transport One system connects each driver mobile application session to a designated vehicle and unified cloud profile. Below is the active roster configured in the system:', body))

drivers_data = [
    [Paragraph('Driver Name', table_header), Paragraph('Phone Number', table_header), Paragraph('Assigned Vehicle', table_header), Paragraph('Cloud Login ID', table_header), Paragraph('Assigned Role & App Access', table_header)],
    [Paragraph('<b>Sandeep</b>', table_cell), Paragraph('+91 63555 83474', table_cell), Paragraph('<b>GJ19Y2720</b>', table_cell), Paragraph('sandeep@transport1.com', table_cell), Paragraph('Primary Line Haul Driver (Full Duty, Nav, Expenses, POD)', table_cell)],
    [Paragraph('<b>Dadarao</b>', table_cell), Paragraph('+91 80077 55389', table_cell), Paragraph('<b>GJ19J6633</b>', table_cell), Paragraph('dadarao@transport1.com', table_cell), Paragraph('Heavy Goods Driver (Attendance, GPS, Sunday Clean, POD)', table_cell)],
    [Paragraph('<b>Ramrao</b>', table_cell), Paragraph('+91 76002 91483', table_cell), Paragraph('<b>GJ19J6633</b>', table_cell), Paragraph('ramrao@transport1.com', table_cell), Paragraph('Relief Driver / Co-Pilot (GPS, Expense Slips, Challan Log)', table_cell)],
    [Paragraph('<b>Devidas</b>', table_cell), Paragraph('+91 97264 23091', table_cell), Paragraph('<b>GJ19Y4628</b>', table_cell), Paragraph('devidas@transport1.com', table_cell), Paragraph('Regional Cargo Driver (Live Route, Pre-Trip Seatbelt, POD)', table_cell)],
    [Paragraph('<b>Ashok Tempo</b>', table_cell), Paragraph('+91 63542 15071', table_cell), Paragraph('<b>GJ19Y0829</b>', table_cell), Paragraph('ashok@transport1.com', table_cell), Paragraph('City Distribution / Tempo (Last-Mile Delivery, Fast POD)', table_cell)],
    [Paragraph('<b>Ajay</b>', table_cell), Paragraph('+91 90812 55626', table_cell), Paragraph('<b>GJ19Z0901</b>', table_cell), Paragraph('ajay@transport1.com', table_cell), Paragraph('Fleet Driver (Full Desk Access, Tyres &amp; Fluids, RTO Memos)', table_cell)],
]

t1 = Table(drivers_data, colWidths=[75, 80, 75, 125, 185])
t1.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), primary_color),
    ('ALIGN', (0,0), (-1,-1), 'LEFT'),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ('TOPPADDING', (0,0), (-1,-1), 4),
    ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
]))
story.append(t1)
story.append(Spacer(1, 10))

# Section 2: Comprehensive Field-by-Field Breakdown
story.append(Paragraph('2. COMPLETE LIST OF ALL DATA RECORDED FROM DRIVERS (10 MODULES)', section_heading))
story.append(Paragraph('Every driver action on the mobile APK is captured with GPS, timestamps, telemetry, and photographic evidence, then synced live to Cloud Firestore for Admin review:', body))

modules = [
    ('1. Duty & Shift Attendance (Duty & Haziri)', [
        ('Start Duty Time', 'Exact timestamp when driver clicks ON DUTY in the morning.'),
        ('End Duty Time', 'Exact timestamp when driver clicks OFF DUTY at night.'),
        ('Total Shift Duration', 'Calculated active duty hours (e.g. 9h 45m).'),
        ('Duty Location (GPS)', 'Latitude/Longitude & Reverse Geocoded address at punch-in/out.'),
        ('Odometer at Start & End', 'Vehicle starting KM and closing KM for daily distance tally.'),
        ('Driver Status', 'Real-time indicator: ON DUTY (Green) or OFF DUTY (Grey).')
    ]),
    ('2. Live GPS & Real-time Telematics (Live GPS Tracking)', [
        ('Real-Time Coordinates', 'Latitude & Longitude updated every 5-10 seconds.'),
        ('Live Vehicle Speed', 'Current driving speed in km/h with overspeed alerts (&gt;60/80 km/h).'),
        ('Movement State', 'Moving (Green), Idle with engine on (Amber), or Stationary/Parked (Red).'),
        ('Ignition / Engine Status', 'Engine ON / OFF sensor data via telematics / phone motion sensors.'),
        ('Battery & Signal Quality', 'Driver phone battery level (%) and network signal reliability.'),
        ('GPS Breadcrumb History', 'Complete historical route trail showing actual path taken vs planned route.')
    ]),
    ('3. Pre-Trip Seatbelt Safety Verification (Seatbelt Photo & AI Verification)', [
        ('Driver Cabin Selfie', 'Live front-camera photo of driver wearing seatbelt before vehicle moves.'),
        ('AI Belt Detection Status', 'Automated ML verification: Belt Detected (Verified) vs Not Found (Violation).'),
        ('Capture Geo-Stamp', 'Precise GPS coordinates where selfie was taken (e.g. Bardoli, Surat).'),
        ('Capture Timestamp', 'Date & exact minute of photo capture (e.g. Tue, 27 Oct 7:12 PM).'),
        ('Trip Lock Mechanism', 'Prevents starting a loaded trip if seatbelt compliance is missing.')
    ]),
    ('4. Sunday Mandatory Vehicle Cleaning (Sunday Gadi Dhulai)', [
        ('Washed Vehicle Photo', 'Photo of cleaned vehicle interior cabin and exterior body.'),
        ('Cleaning Submission Date', 'Deduplication check ensuring cleaning is logged every Sunday.'),
        ('Washing Location Stamp', 'GPS location of wash station or company parking bay.'),
        ('Admin Approval Status', 'Pending / Verified / Needs Re-wash indicator.')
    ]),
    ('5. Live Trip Progress & Waypoint Navigation (Trip & Turn-by-Turn Nav)', [
        ('Trip ID & Cargo Consignment', 'Linked Trip Number (e.g. LIVE-GJ19Y2720 / TRP-1049).'),
        ('Remaining Distance', 'Accurate highway/road distance to delivery point in kilometers (e.g. 45.2 km).'),
        ('Estimated Time of Arrival (ETA)', 'Live traffic-adjusted arrival time (e.g. 18:30 PM).'),
        ('Next Turn Direction', 'Live maneuver card (e.g. 1.2 km baad baayein mudein / Turn Left).'),
        ('Pickup & Drop Geo-Fences', 'Automatic timestamp logged when truck enters 200m of customer site.')
    ]),
    ('6. Digital Proof of Delivery - POD (Bilty / Delivery Receipt)', [
        ('Signed LR / Bilty Photo', 'High-res image of customer signed and stamped receiving copy.'),
        ('Receiving Person Name', 'Full name of person who received the goods at warehouse/factory.'),
        ('Receiver Phone Number', 'Contact mobile number for automated delivery confirmation SMS.'),
        ('Delivered vs Short/Damaged Quantity', 'Pieces received intact, shortage quantity, and damage notes.'),
        ('Delivery Timestamp & Location', 'Irrefutable GPS and time stamp proving on-site unloading.')
    ]),
    ('7. Enroute Trip Expenses & Diesel Slips (Diesel & Road Expenses)', [
        ('Diesel Purchase Slip Photo', 'Receipt photo showing fuel pump name, date, and liters pumped.'),
        ('Fuel Amount (Rs) & Liters', 'Total rupees spent and fuel quantity for mileage calculation (km/L).'),
        ('Toll Plaza Payments', 'Fastag / Cash toll receipts uploaded with toll plaza name.'),
        ('Driver Bhatta & Night Halt', 'Food allowance, room rent, and enroute vehicle maintenance.'),
        ('Payment Mode', 'Company Fastag, Driver Cash, or UPI QR code scan transaction.')
    ]),
    ('8. Police / RTO Challan & Memos (Police / RTO Challan)', [
        ('Challan Slip Photo', 'High-resolution photo of traffic police or RTO citation slip.'),
        ('Fine Amount (Rs)', 'Exact monetary fine levied by authority.'),
        ('Violation Reason', 'Overloading, lane cutting, missing PUC, parking, or overspeeding.'),
        ('Date, Time & Exact Location', 'Intersection / Highway NH location where challan was issued.'),
        ('Payment Status', 'Paid by Driver enroute / Pending Head Office settlement.')
    ]),
    ('9. Daily Vehicle Fluids & Tyre Inspections (Daily Vehicle Check)', [
        ('Engine Oil & Coolant Level', 'OK / LOW status checked each morning before starting.'),
        ('DEF (AdBlue) Level', 'Diesel Exhaust Fluid tank percentage.'),
        ('Brake & Clutch Fluid', 'Hydraulic fluid pressure check status.'),
        ('Tyre Replacement & Condition', 'KM reading when tyre changed, tyre position (Front Left, Rear Right, etc.).')
    ]),
    ('10. Driver Identity, License & Compliance (DL & Insurance)', [
        ('Driving License (DL)', 'DL number, expiry date, and scanned photo of physical card.'),
        ('Driver Medical & Bima Policy', 'Insurance policy number and medical validity date.'),
        ('Emergency Contact', 'Relative name and phone number for accidents or emergency rescue.')
    ])
]

for title, fields in modules:
    mod_story = []
    mod_story.append(Paragraph(title, sub_heading))
    mod_table_data = [[Paragraph('Data Field Name', table_header), Paragraph('System Purpose, Capture Method &amp; Admin Value', table_header)]]
    for fn, desc in fields:
        mod_table_data.append([Paragraph('<b>' + fn + '</b>', table_cell_bold), Paragraph(desc, table_cell)])
    
    t_mod = Table(mod_table_data, colWidths=[150, 390])
    t_mod.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), secondary_color),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
    ]))
    mod_story.append(t_mod)
    mod_story.append(Spacer(1, 6))
    story.append(KeepTogether(mod_story))

# Page Break for Architecture & Sync Guide
story.append(PageBreak())

# Section 3: Data Architecture & Live Sync Explanation
story.append(Paragraph('3. DATA FLOW: HOW DRIVER MOBILE DATA REACHES ADMIN PC', section_heading))
story.append(Paragraph('The system uses a 4-tier real-time synchronisation pipeline ensuring 100% data fidelity between driver phones and head-office dashboards:', body))

flow_steps = [
    [Paragraph('Step', table_header), Paragraph('Tier', table_header), Paragraph('Process &amp; Data Handshake', table_header), Paragraph('Network Fallback', table_header)],
    [Paragraph('1', table_cell_center), Paragraph('<b>Driver Phone (APK)</b>', table_cell), Paragraph('Driver captures photos, punches duty, or navigates. App saves record to local SQLite/Hive database instantly.', table_cell), Paragraph('Works 100% offline without 4G.', table_cell)],
    [Paragraph('2', table_cell_center), Paragraph('<b>Cloud Firestore Sync</b>', table_cell), Paragraph('As soon as 4G/WiFi is available, encrypted SSL stream uploads record to Google Cloud Firestore database.', table_cell), Paragraph('Auto-retry with backoff.', table_cell)],
    [Paragraph('3', table_cell_center), Paragraph('<b>Security Rules Engine</b>', table_cell), Paragraph('Firebase rules validate driver identity, ensure no cross-company data leakage, and index records.', table_cell), Paragraph('Token validation enforced.', table_cell)],
    [Paragraph('4', table_cell_center), Paragraph('<b>Admin Dashboard (Web/PC)</b>', table_cell), Paragraph('Admin web console receives live real-time snapshot listener update without needing to refresh page.', table_cell), Paragraph('Zero delay live notifications.', table_cell)],
]
t_flow = Table(flow_steps, colWidths=[35, 115, 270, 120])
t_flow.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), primary_color),
    ('ALIGN', (0,0), (-1,-1), 'LEFT'),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ('TOPPADDING', (0,0), (-1,-1), 4),
    ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
]))
story.append(t_flow)
story.append(Spacer(1, 10))

# Section 4: Admin Navigation Matrix
story.append(Paragraph('4. ADMIN CONSOLE: WHERE TO VIEW EACH DATA CATEGORY', section_heading))
story.append(Paragraph('To monitor your fleet, open the Transport One Web or Mobile app and navigate to these dedicated screens:', body))

admin_matrix = [
    [Paragraph('Data Module', table_header), Paragraph('Screen / Tab Name', table_header), Paragraph('Key Features Available to Admin', table_header)],
    [Paragraph('<b>Live Tracking &amp; ETA</b>', table_cell), Paragraph('Live Route / Map Workspace', table_cell), Paragraph('Satellite map, 100% smooth road polyline, live speed gauge, breadcrumbs, remaining KM.', table_cell)],
    [Paragraph('<b>Driver Desk &amp; Photos</b>', table_cell), Paragraph('Driver Desk Tab', table_cell), Paragraph('Seatbelt photos with AI badges, Sunday cleaning gallary, RTO challan slips, daily fluids.', table_cell)],
    [Paragraph('<b>Trips &amp; Proof of Delivery</b>', table_cell), Paragraph('Trips &amp; Consignments Tab', table_cell), Paragraph('Trip creation, vehicle assignment, customer POD download, shortage/damage reports.', table_cell)],
    [Paragraph('<b>Financials &amp; Diesel</b>', table_cell), Paragraph('Expenses &amp; Accounts Tab', table_cell), Paragraph('Fuel bill approval, toll deduction audit, driver bhatta settlement, total trip cost.', table_cell)],
    [Paragraph('<b>Driver Compliance</b>', table_cell), Paragraph('Fleet &amp; Driver Profile Tab', table_cell), Paragraph('DL expiration alerts, insurance renewal countdown, emergency contact directory.', table_cell)],
]
t_admin = Table(admin_matrix, colWidths=[130, 150, 260])
t_admin.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), secondary_color),
    ('ALIGN', (0,0), (-1,-1), 'LEFT'),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ('TOPPADDING', (0,0), (-1,-1), 4),
    ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, light_bg]),
]))
story.append(t_admin)
story.append(Spacer(1, 14))

# Footer notice
story.append(HRFlowable(width='100%', thickness=1, color=colors.HexColor('#94A3B8'), spaceAfter=6))
story.append(Paragraph('<i>Generated automatically by Transport One Fleet Management Suite. All telematics, photo uploads, and location coordinates are protected by Cloud Firestore enterprise security rules.</i>', ParagraphStyle('Footer', parent=styles['Italic'], fontSize=7.5, leading=10, textColor=colors.HexColor('#64748B'), alignment=1)))

doc.build(story)
print('PDF GENERATION COMPLETE')

