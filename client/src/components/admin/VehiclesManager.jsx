import React, { useState, useEffect } from 'react';
import { 
  Truck, 
  Plus, 
  Search, 
  CheckCircle2, 
  AlertTriangle, 
  ShieldCheck, 
  Fuel, 
  Gauge, 
  Edit2, 
  Archive, 
  RotateCcw,
  X
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

export default function VehiclesManager({ vehicles = [], onCreateVehicle, onRefreshVehicles }) {
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [showArchived, setShowArchived] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState(null);

  // Form states
  const [formData, setFormData] = useState({
    registrationNumber: '',
    type: 'van',
    model: '',
    maxWeightKg: '1500',
    fuelType: 'diesel',
    odometer: '42000',
    maintenanceStatus: 'optimal'
  });

  const filteredVehicles = vehicles.filter(v => {
    const q = searchTerm.toLowerCase();
    const matchesSearch = 
      v.registrationNumber.toLowerCase().includes(q) ||
      (v.model && v.model.toLowerCase().includes(q)) ||
      v.id.toLowerCase().includes(q);
    const matchesType = typeFilter === 'all' || (v.type || '').toLowerCase() === typeFilter.toLowerCase();
    const matchesArchive = showArchived ? true : v.status !== 'archived';

    return matchesSearch && matchesType && matchesArchive;
  });

  const handleOpenAdd = () => {
    setEditingVehicle(null);
    setFormData({
      registrationNumber: '',
      type: 'van',
      model: '',
      maxWeightKg: '1500',
      fuelType: 'diesel',
      odometer: '42000',
      maintenanceStatus: 'optimal'
    });
    setShowModal(true);
  };

  const handleOpenEdit = (veh) => {
    setEditingVehicle(veh);
    setFormData({
      registrationNumber: veh.registrationNumber,
      type: veh.type || 'van',
      model: veh.model || '',
      maxWeightKg: String(veh.maxWeightKg || 1500),
      fuelType: veh.fuelType || 'diesel',
      odometer: String(veh.odometer || 40000),
      maintenanceStatus: veh.maintenanceStatus || 'optimal'
    });
    setShowModal(true);
  };

  const handleFormSubmit = async (e) => {
    e.preventDefault();
    soundEffects.playActionClick();

    if (!formData.registrationNumber || !formData.model) return;

    try {
      if (editingVehicle) {
        await api.updateVehicle(editingVehicle.id, {
          registrationNumber: formData.registrationNumber.toUpperCase().trim(),
          type: formData.type.toLowerCase(),
          model: formData.model,
          maxWeightKg: parseInt(formData.maxWeightKg, 10) || 1500,
          fuelType: formData.fuelType,
          odometer: parseInt(formData.odometer, 10) || 40000,
          maintenanceStatus: formData.maintenanceStatus
        });
      } else {
        await api.createVehicle({
          registrationNumber: formData.registrationNumber.toUpperCase().trim(),
          type: formData.type.toLowerCase(),
          model: formData.model,
          maxWeightKg: parseInt(formData.maxWeightKg, 10) || 1500,
          fuelType: formData.fuelType,
          odometer: parseInt(formData.odometer, 10) || 40000,
          maintenanceStatus: formData.maintenanceStatus
        });
      }

      soundEffects.playSuccessChime();
      setShowModal(false);
      if (onRefreshVehicles) onRefreshVehicles();
    } catch (err) {
      console.error('Failed to save vehicle:', err);
    }
  };

  const handleArchiveToggle = async (veh) => {
    soundEffects.playActionClick();
    try {
      await api.archiveVehicle(veh.id);
      soundEffects.playSuccessChime();
      if (onRefreshVehicles) onRefreshVehicles();
    } catch (err) {
      console.error('Failed to archive vehicle:', err);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Fleet Vehicles &amp; Transport Assets
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Manage commercial vans, payload capacity ratings, maintenance readiness, fuel profiles, and driver allocations.
          </p>
        </div>

        <button
          onClick={handleOpenAdd}
          className="btn btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
        >
          <Plus size={16} />
          Register Fleet Vehicle
        </button>
      </div>

      {/* Filter and Search */}
      <div style={{
        background: '#ffffff',
        padding: '14px 18px',
        borderRadius: '12px',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '12px',
        boxShadow: 'var(--shadow-subtle)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: 1, minWidth: '240px' }}>
          <Search size={16} color="var(--slate-400)" />
          <input
            type="text"
            placeholder="Search by registration number, model, or vehicle ID..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              border: 'none',
              outline: 'none',
              fontSize: '13px',
              width: '100%',
              color: 'var(--navy-800)'
            }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontWeight: 600 }}>Type:</span>
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
              style={{
                background: 'var(--slate-50)',
                border: '1px solid var(--slate-300)',
                borderRadius: '8px',
                padding: '6px 12px',
                fontSize: '12px',
                fontWeight: 600,
                color: 'var(--navy-800)'
              }}
            >
              <option value="all">All Body Types</option>
              <option value="van">Delivery Van</option>
              <option value="truck">Mini Truck</option>
              <option value="lcv">LCV / Heavy</option>
            </select>
          </div>

          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--slate-600)', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={showArchived}
              onChange={(e) => setShowArchived(e.target.checked)}
            />
            <span>Show Archived</span>
          </label>
        </div>
      </div>

      {/* Vehicles Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: '16px' }}>
        {filteredVehicles.length === 0 ? (
          <div style={{
            gridColumn: '1 / -1',
            background: '#ffffff',
            borderRadius: '12px',
            padding: '40px',
            textAlign: 'center',
            color: 'var(--slate-400)',
            border: '1px solid var(--slate-200)'
          }}>
            No vehicles found matching criteria.
          </div>
        ) : (
          filteredVehicles.map(veh => {
            const isArchived = veh.status === 'archived';
            const isOptimal = (veh.maintenanceStatus || '').toLowerCase() === 'optimal';

            return (
              <div
                key={veh.id}
                style={{
                  background: '#ffffff',
                  borderRadius: '14px',
                  padding: '18px',
                  border: '1px solid var(--slate-200)',
                  boxShadow: 'var(--shadow-card)',
                  opacity: isArchived ? 0.65 : 1,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px'
                }}
              >
                {/* Header */}
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{
                      width: '42px',
                      height: '42px',
                      borderRadius: '10px',
                      background: 'var(--navy-800)',
                      color: '#ffffff',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      <Truck size={22} />
                    </div>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)' }}>
                        {veh.registrationNumber}
                      </h3>
                      <div style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                        {veh.model}
                      </div>
                    </div>
                  </div>

                  <span style={{
                    fontSize: '10px',
                    fontWeight: 800,
                    padding: '3px 8px',
                    borderRadius: '9999px',
                    textTransform: 'uppercase',
                    background: veh.availability === 'available' ? 'var(--status-emerald-light)' : (veh.availability === 'assigned' ? 'var(--sky-blue-light)' : 'var(--slate-100)'),
                    color: veh.availability === 'available' ? 'var(--status-emerald-text)' : (veh.availability === 'assigned' ? 'var(--primary-blue)' : 'var(--slate-600)')
                  }}>
                    {veh.availability || 'Available'}
                  </span>
                </div>

                {/* Metrics */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '8px',
                  background: 'var(--slate-50)',
                  padding: '10px 12px',
                  borderRadius: '10px',
                  border: '1px solid var(--slate-200)',
                  fontSize: '12px'
                }}>
                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Max Payload</span>
                    <div style={{ fontWeight: 800, color: 'var(--navy-800)' }}>
                      {veh.maxWeightKg} kg
                    </div>
                  </div>

                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Odometer</span>
                    <div style={{ fontWeight: 800, color: 'var(--navy-800)' }}>
                      {Number(veh.odometer).toLocaleString()} km
                    </div>
                  </div>

                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Fuel System</span>
                    <div style={{ fontWeight: 700, color: 'var(--navy-800)', textTransform: 'capitalize' }}>
                      {veh.fuelType || 'Diesel'}
                    </div>
                  </div>

                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Maintenance</span>
                    <div style={{ fontWeight: 800, color: isOptimal ? 'var(--status-emerald-text)' : 'var(--status-amber-text)', textTransform: 'capitalize' }}>
                      {veh.maintenanceStatus || 'Optimal'}
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '8px', paddingTop: '6px', borderTop: '1px solid var(--slate-100)', marginTop: 'auto' }}>
                  <button
                    onClick={() => handleOpenEdit(veh)}
                    className="btn btn-secondary"
                    style={{ padding: '5px 10px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                  >
                    <Edit2 size={12} />
                    <span>Edit</span>
                  </button>

                  <button
                    onClick={() => handleArchiveToggle(veh)}
                    className="btn btn-secondary"
                    style={{ padding: '5px 10px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                  >
                    {isArchived ? <RotateCcw size={12} color="var(--primary-teal)" /> : <Archive size={12} color="var(--status-rose)" />}
                    <span>{isArchived ? 'Restore' : 'Archive'}</span>
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Modal */}
      {showModal && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(15, 23, 42, 0.6)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '16px',
          zIndex: 9999
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            width: '100%',
            maxWidth: '480px',
            boxShadow: 'var(--shadow-modal)',
            overflow: 'hidden'
          }}>
            <div style={{
              background: '#ffffff',
              color: 'var(--navy-900)',
              borderBottom: '1px solid var(--slate-200)',
              padding: '18px 20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-900)' }}>
                  {editingVehicle ? 'गाड़ी विवरण बदलें (Edit Vehicle)' : 'नई गाड़ी जोड़ें (Register Vehicle)'}
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                  गाड़ी का नंबर, मॉडल और क्षमता दर्ज करें
                </p>
              </div>
              <button
                onClick={() => setShowModal(false)}
                style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleFormSubmit} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    गाड़ी नंबर (Registration No) *
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.registrationNumber}
                    onChange={(e) => setFormData({ ...formData, registrationNumber: e.target.value })}
                    placeholder="HR-26-EC-9014"
                    className="form-control"
                    style={{ textTransform: 'uppercase' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    गाड़ी का प्रकार (Body Type)
                  </label>
                  <select
                    value={formData.type}
                    onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                    className="form-control"
                  >
                    <option value="van">डिलीवरी वैन (Delivery Van)</option>
                    <option value="truck">मिनी ट्रक (Mini Truck / Chhota Hathi)</option>
                    <option value="lcv">बड़ा ट्रक (Freight / LCV)</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  मेक और मॉडल (Make &amp; Model) *
                </label>
                <input
                  type="text"
                  required
                  value={formData.model}
                  onChange={(e) => setFormData({ ...formData, model: e.target.value })}
                  placeholder="उदा. Tata Ace Gold 2.0 / Bolero Pickup"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    वजन क्षमता (Max Payload KG)
                  </label>
                  <input
                    type="number"
                    min="100"
                    value={formData.maxWeightKg}
                    onChange={(e) => setFormData({ ...formData, maxWeightKg: e.target.value })}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    ईंधन (Fuel Type)
                  </label>
                  <select
                    value={formData.fuelType}
                    onChange={(e) => setFormData({ ...formData, fuelType: e.target.value })}
                    className="form-control"
                  >
                    <option value="diesel">डीजल (Diesel)</option>
                    <option value="cng">सीएनजी (CNG)</option>
                    <option value="electric">इलेक्ट्रिक (Electric EV)</option>
                    <option value="petrol">पेट्रोल (Petrol)</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    ओडोमीटर (Odometer KM)
                  </label>
                  <input
                    type="number"
                    value={formData.odometer}
                    onChange={(e) => setFormData({ ...formData, odometer: e.target.value })}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    मेंटेनेंस स्थिति (Fitness Status)
                  </label>
                  <select
                    value={formData.maintenanceStatus}
                    onChange={(e) => setFormData({ ...formData, maintenanceStatus: e.target.value })}
                    className="form-control"
                  >
                    <option value="optimal">सक्रिय / सही (Optimal / Ready)</option>
                    <option value="service_due">सर्विस बाकी (Service Due)</option>
                    <option value="under_repair">वर्कशॉप में (In Repair)</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                >
                  {editingVehicle ? 'Save Changes' : 'Register Vehicle'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
