import React, { useState, useEffect } from 'react';
import { 
  Users, 
  Phone, 
  Truck, 
  CheckCircle2, 
  AlertCircle, 
  Plus, 
  Search, 
  ShieldCheck, 
  Edit2, 
  Archive, 
  RotateCcw, 
  KeyRound, 
  Lock, 
  Mail, 
  UserCheck, 
  UserX,
  X
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

export default function DriversManager({ drivers = [], onCreateDriver, onRefreshDrivers }) {
  const [activeSubTab, setActiveSubTab] = useState('roster'); // 'roster' | 'accounts'
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingDriver, setEditingDriver] = useState(null);

  // Driver form states
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [licenseNumber, setLicenseNumber] = useState('');
  const [emergencyContact, setEmergencyContact] = useState('');
  const [assignedVehicleId, setAssignedVehicleId] = useState('');
  const [vehicles, setVehicles] = useState([]);

  // User Accounts State
  const [userAccounts, setUserAccounts] = useState([]);
  const [loadingAccounts, setLoadingAccounts] = useState(false);
  const [showAddAccountModal, setShowAddAccountModal] = useState(false);
  const [accountFormData, setAccountFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: 'DriverPassword123!',
    role: 'driver',
    driverId: ''
  });
  const [accountError, setAccountError] = useState('');
  const [accountSuccess, setAccountSuccess] = useState('');

  // Edit User Account state
  const [showEditAccountModal, setShowEditAccountModal] = useState(false);
  const [editingAccount, setEditingAccount] = useState(null);
  const [editAccountFormData, setEditAccountFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    role: 'driver',
    driverId: '',
    status: 'active'
  });
  const [isAutoProvisioning, setIsAutoProvisioning] = useState(false);

  const loadVehiclesAndUsers = async () => {
    try {
      const [vehs, users] = await Promise.all([
        api.getVehicles().catch(() => []),
        api.getUsers().catch(() => [])
      ]);
      setVehicles(vehs);
      setUserAccounts(users);
    } catch (err) {
      console.error('Failed to load vehicles or users:', err);
    }
  };

  useEffect(() => {
    loadVehiclesAndUsers();
  }, []);

  const filteredDrivers = drivers.filter(d => {
    const q = searchTerm.toLowerCase();
    const matchesSearch = 
      d.name.toLowerCase().includes(q) ||
      d.id.toLowerCase().includes(q) ||
      (d.licenseNumber && d.licenseNumber.toLowerCase().includes(q));
    const matchesStatus = statusFilter === 'all' || (d.availability || 'available').toLowerCase() === statusFilter.toLowerCase();
    return matchesSearch && matchesStatus;
  });

  const handleOpenAdd = () => {
    setEditingDriver(null);
    setName('');
    setPhone('');
    setLicenseNumber('');
    setEmergencyContact('');
    setAssignedVehicleId('');
    setShowAddModal(true);
  };

  const handleOpenEdit = (driver) => {
    setEditingDriver(driver);
    setName(driver.name);
    setPhone(driver.phone);
    setLicenseNumber(driver.licenseNumber);
    setEmergencyContact(driver.emergencyContact || '');
    setAssignedVehicleId(driver.assignedVehicleId || '');
    setShowAddModal(true);
  };

  const handleDriverSubmit = async (e) => {
    e.preventDefault();
    soundEffects.playActionClick();

    if (!name || !phone || !licenseNumber) return;

    try {
      if (editingDriver) {
        await api.updateDriver(editingDriver.id, {
          name,
          phone,
          licenseNumber,
          emergencyContact,
          assignedVehicleId: assignedVehicleId || null
        });
      } else {
        await api.createDriver({
          name,
          phone,
          licenseNumber,
          emergencyContact,
          assignedVehicleId: assignedVehicleId || null
        });
      }

      soundEffects.playSuccessChime();
      setShowAddModal(false);
      if (onRefreshDrivers) onRefreshDrivers();
    } catch (err) {
      console.error('Failed to save driver:', err);
    }
  };

  const handleArchiveToggle = async (driver) => {
    soundEffects.playActionClick();
    try {
      await api.archiveDriver(driver.id);
      soundEffects.playSuccessChime();
      if (onRefreshDrivers) onRefreshDrivers();
    } catch (err) {
      console.error('Failed to archive driver:', err);
    }
  };

  // User Accounts Actions
  const handleToggleUserStatus = async (user) => {
    soundEffects.playActionClick();
    const nextStatus = user.status === 'active' ? 'disabled' : 'active';
    try {
      await api.updateUserStatus(user.id, nextStatus);
      soundEffects.playSuccessChime();
      setUserAccounts(prev => prev.map(u => u.id === user.id ? { ...u, status: nextStatus } : u));
    } catch (err) {
      console.error('Failed to update user status:', err);
    }
  };

  const handleCreateAccountSubmit = async (e) => {
    e.preventDefault();
    setAccountError('');
    soundEffects.playActionClick();

    try {
      const res = await api.createUser(accountFormData);
      soundEffects.playSuccessChime();
      setAccountSuccess(`Account for ${res.user.name} created successfully.`);
      setShowAddAccountModal(false);
      setAccountFormData({
        name: '',
        email: '',
        phone: '',
        password: 'DriverPassword123!',
        role: 'driver',
        driverId: ''
      });
      loadVehiclesAndUsers();
      setTimeout(() => setAccountSuccess(''), 3000);
    } catch (err) {
      setAccountError(err.message || 'Failed to create user account.');
    }
  };

  // Open Edit User Account Modal
  const handleOpenEditAccount = (user) => {
    setEditingAccount(user);
    setEditAccountFormData({
      name: user.name || '',
      email: user.email || '',
      phone: user.phone || '',
      role: user.role || 'driver',
      driverId: user.driverId || '',
      status: user.status || 'active',
      password: ''
    });
    setAccountError('');
    setShowEditAccountModal(true);
  };

  const handleEditAccountSubmit = async (e) => {
    e.preventDefault();
    setAccountError('');
    soundEffects.playActionClick();

    try {
      const payload = {
        name: editAccountFormData.name.trim(),
        email: editAccountFormData.email.trim(),
        phone: editAccountFormData.phone.trim(),
        driverId: editAccountFormData.driverId || null,
        status: editAccountFormData.status
      };
      if (editAccountFormData.password && editAccountFormData.password.trim()) {
        payload.password = editAccountFormData.password.trim();
      }

      await api.updateUser(editingAccount.id, payload);
      soundEffects.playSuccessChime();
      setAccountSuccess(`Account credentials for "${payload.name}" updated successfully.`);
      setShowEditAccountModal(false);
      setEditingAccount(null);
      loadVehiclesAndUsers();
      setTimeout(() => setAccountSuccess(''), 4000);
    } catch (err) {
      setAccountError(err.message || 'Failed to update user account.');
    }
  };

  // 1-Click Auto Provision Accounts for All Drivers
  const handleAutoProvision = async () => {
    setIsAutoProvisioning(true);
    setAccountError('');
    soundEffects.playActionClick();
    try {
      const res = await api.autoProvisionDriverAccounts();
      soundEffects.playSuccessChime();
      const credentials = Array.isArray(res.created)
        ? res.created.map(item => `${item.email}  |  ${item.temporaryPassword}`).join('\n')
        : '';
      setAccountSuccess(
        res.count > 0
          ? `Provisioned ${res.count} driver account(s). Copy these one-time credentials now; they will not be shown again:\n${credentials}`
          : 'No accounts were created; every active driver already has a login account.'
      );
      loadVehiclesAndUsers();
    } catch (err) {
      setAccountError(err.message || 'Failed to auto-provision driver accounts.');
    } finally {
      setIsAutoProvisioning(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Driver Roster &amp; Personnel Security
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Manage commercial driver roster profiles, license credentials, vehicle allocations, and user login accounts.
          </p>
        </div>

        {activeSubTab === 'roster' ? (
          <button
            onClick={handleOpenAdd}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
          >
            <Plus size={16} />
            Register Driver Profile
          </button>
        ) : (
          <button
            onClick={() => setShowAddAccountModal(true)}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
          >
            <Plus size={16} />
            Create Driver Login Account
          </button>
        )}
      </div>

      {/* Sub-Tab Navigation Bar */}
      <div style={{ display: 'flex', gap: '8px', borderBottom: '1px solid var(--slate-200)', paddingBottom: '8px' }}>
        <button
          onClick={() => setActiveSubTab('roster')}
          className={`btn ${activeSubTab === 'roster' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '6px' }}
        >
          <Users size={15} />
          <span>Driver Personnel Roster ({drivers.length})</span>
        </button>

        <button
          onClick={() => setActiveSubTab('accounts')}
          className={`btn ${activeSubTab === 'accounts' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '13px', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '6px' }}
        >
          <KeyRound size={15} />
          <span>Driver User Accounts ({userAccounts.filter(u => u.role === 'driver').length})</span>
        </button>
      </div>

      {accountSuccess && (
        <div style={{
          background: 'var(--status-emerald-light)',
          border: '1px solid rgba(16, 185, 129, 0.4)',
          borderRadius: '10px',
          padding: '12px 16px',
          color: 'var(--status-emerald-text)',
          fontSize: '13px',
          fontWeight: 700,
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          <CheckCircle2 size={18} />
          <span style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{accountSuccess}</span>
        </div>
      )}

      {/* --- TAB 1: DRIVER PERSONNEL ROSTER --- */}
      {activeSubTab === 'roster' && (
        <>
          {/* Filter and Search Bar */}
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
                placeholder="Search by name, driver ID, or license number..."
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

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontWeight: 600 }}>Availability:</span>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
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
                <option value="all">All Statuses</option>
                <option value="available">Available</option>
                <option value="on_trip">On Trip</option>
                <option value="on_duty">On Duty</option>
                <option value="off_duty">Off Duty</option>
              </select>
            </div>
          </div>

          {/* Drivers Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: '16px' }}>
            {filteredDrivers.length === 0 ? (
              <div style={{
                gridColumn: '1 / -1',
                background: '#ffffff',
                borderRadius: '12px',
                padding: '40px',
                textAlign: 'center',
                color: 'var(--slate-400)',
                border: '1px solid var(--slate-200)'
              }}>
                No drivers found matching criteria.
              </div>
            ) : (
              filteredDrivers.map(drv => {
                const assignedVehicle = vehicles.find(v => v.id === drv.assignedVehicleId);
                const isArchived = drv.status === 'archived';
                const hasLocation = drv.currentLocation && drv.currentLocation.lat;

                return (
                  <div
                    key={drv.id}
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
                          borderRadius: '50%',
                          background: 'var(--navy-800)',
                          color: '#ffffff',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontWeight: 800,
                          fontSize: '16px'
                        }}>
                          {drv.name.charAt(0)}
                        </div>
                        <div>
                          <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>
                            {drv.name}
                          </h3>
                          <div style={{ fontSize: '11px', color: 'var(--slate-400)', fontFamily: 'var(--font-mono)' }}>
                            {drv.id}
                          </div>
                        </div>
                      </div>

                      <span style={{
                        fontSize: '10px',
                        fontWeight: 800,
                        padding: '3px 8px',
                        borderRadius: '9999px',
                        textTransform: 'uppercase',
                        background: drv.availability === 'available' ? 'var(--status-emerald-light)' : (drv.availability === 'on_trip' ? 'var(--sky-blue-light)' : 'var(--slate-100)'),
                        color: drv.availability === 'available' ? 'var(--status-emerald-text)' : (drv.availability === 'on_trip' ? 'var(--primary-blue)' : 'var(--slate-600)')
                      }}>
                        {drv.availability || 'Available'}
                      </span>
                    </div>

                    {/* Contact & License Info */}
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
                        <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Phone</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>
                          <a href={`tel:${drv.phone}`} style={{ color: 'var(--primary-blue)', textDecoration: 'none' }}>
                            {drv.phone}
                          </a>
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>License</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)', fontSize: '11px' }}>
                          {drv.licenseNumber}
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Assigned Vehicle</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>
                          {assignedVehicle?.registrationNumber || drv.assignedVehicleId || 'None'}
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>Location Status</span>
                        <div style={{ fontWeight: 700, color: hasLocation ? 'var(--status-emerald-text)' : 'var(--slate-400)' }}>
                          {hasLocation ? (drv.lastLocationUpdate ? 'Live GPS' : 'Position Known') : 'Unavailable'}
                        </div>
                      </div>
                    </div>

                    {/* Actions */}
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '8px', paddingTop: '6px', borderTop: '1px solid var(--slate-100)', marginTop: 'auto' }}>
                      <button
                        onClick={() => handleOpenEdit(drv)}
                        className="btn btn-secondary"
                        style={{ padding: '5px 10px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                      >
                        <Edit2 size={12} />
                        <span>Edit</span>
                      </button>

                      <button
                        onClick={() => handleArchiveToggle(drv)}
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
        </>
      )}

      {/* --- TAB 2: DRIVER USER ACCOUNTS --- */}
      {activeSubTab === 'accounts' && (
        <div style={{
          background: '#ffffff',
          borderRadius: '12px',
          border: '1px solid var(--slate-200)',
          overflow: 'hidden',
          boxShadow: 'var(--shadow-card)'
        }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--slate-200)', background: 'var(--slate-50)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '10px' }}>
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>
                ड्राइवर लॉगिन अकाउंट (Driver Authentication Credentials)
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                ड्राइवर मोबाइल ऐप में लॉगिन करने के लिए क्रेडेंशियल्स प्रबंधित और एडिट करें।
              </p>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
              <button
                type="button"
                onClick={handleAutoProvision}
                disabled={isAutoProvisioning}
                className="btn btn-secondary"
                style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 14px', fontSize: '12px', fontWeight: 700 }}
              >
                <KeyRound size={14} color="var(--primary-teal)" />
                <span>{isAutoProvisioning ? 'Provisioning...' : 'सभी ड्राइवरों के लॉगिन बनाएं (Auto-Provision)'}</span>
              </button>
              <button
                onClick={() => setShowAddAccountModal(true)}
                className="btn btn-primary"
                style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 14px', fontSize: '12px', fontWeight: 700 }}
              >
                <Plus size={15} />
                <span>+ नया ड्राइवर लॉगिन बनाएं (Create Account)</span>
              </button>
            </div>
          </div>

          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
              <thead>
                <tr style={{ background: 'var(--slate-50)', borderBottom: '1px solid var(--slate-200)', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  <th style={{ padding: '12px 16px' }}>Personnel &amp; Name</th>
                  <th style={{ padding: '12px 16px' }}>Login Email / Phone</th>
                  <th style={{ padding: '12px 16px' }}>Linked Driver ID</th>
                  <th style={{ padding: '12px 16px' }}>Account Status</th>
                  <th style={{ padding: '12px 16px', textAlign: 'right' }}>Security Actions</th>
                </tr>
              </thead>
              <tbody>
                {userAccounts.filter(u => u.role === 'driver').length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ padding: '36px 20px', textAlign: 'center' }}>
                      <div style={{ maxWidth: '420px', margin: '0 auto', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' }}>
                        <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'var(--slate-100)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-500)' }}>
                          <KeyRound size={22} />
                        </div>
                        <div style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-900)' }}>
                          कोई ड्राइवर लॉगिन अकाउंट नहीं है (No Driver Accounts)
                        </div>
                        <div style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                          ड्राइवर को फोन ऐप में लॉगिन करने के लिए आईडी और पासवर्ड की जरूरत होती है। नीचे दिए गए बटन पर क्लिक करके तुरंत ड्राइवर अकाउंट बनाएं।
                        </div>
                        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', justifyContent: 'center', marginTop: '6px' }}>
                          <button
                            type="button"
                            onClick={handleAutoProvision}
                            disabled={isAutoProvisioning}
                            className="btn btn-secondary"
                            style={{ padding: '9px 16px', fontSize: '12px', fontWeight: 700 }}
                          >
                            <KeyRound size={14} color="var(--primary-teal)" />
                            <span>सभी ड्राइवरों के लॉगिन बनाएं (1-Click Auto-Provision)</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setShowAddAccountModal(true)}
                            className="btn btn-primary"
                            style={{ padding: '9px 16px', fontSize: '12px', fontWeight: 700 }}
                          >
                            + नया ड्राइवर अकाउंट बनाएं
                          </button>
                        </div>
                      </div>
                    </td>
                  </tr>
                ) : (
                userAccounts.filter(u => u.role === 'driver').map(user => {
                  const isDisabled = user.status === 'disabled';
                  return (
                    <tr key={user.id} style={{ borderBottom: '1px solid var(--slate-100)', background: isDisabled ? 'var(--slate-50)' : '#ffffff' }}>
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ fontWeight: 800, color: 'var(--navy-800)' }}>
                          {user.name}
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--slate-400)', fontFamily: 'var(--font-mono)' }}>
                          {user.id}
                        </div>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ fontSize: '12px', color: 'var(--navy-800)', fontWeight: 600 }}>
                          {user.email}
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                          {user.phone || 'No phone'}
                        </div>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <span style={{
                          fontSize: '11px',
                          fontWeight: 700,
                          fontFamily: 'var(--font-mono)',
                          padding: '3px 8px',
                          borderRadius: '6px',
                          background: 'var(--slate-100)',
                          color: 'var(--slate-700)'
                        }}>
                          {user.driverId || 'Unlinked'}
                        </span>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <span style={{
                          fontSize: '11px',
                          fontWeight: 800,
                          padding: '3px 8px',
                          borderRadius: '9999px',
                          textTransform: 'uppercase',
                          background: isDisabled ? 'var(--status-rose-light)' : 'var(--status-emerald-light)',
                          color: isDisabled ? 'var(--status-rose-text)' : 'var(--status-emerald-text)'
                        }}>
                          {isDisabled ? 'Disabled' : 'Active'}
                        </span>
                      </td>

                      <td style={{ padding: '14px 16px', textAlign: 'right', whiteSpace: 'nowrap' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '8px' }}>
                          <button
                            type="button"
                            onClick={() => handleOpenEditAccount(user)}
                            className="btn btn-secondary"
                            style={{
                              padding: '6px 12px',
                              fontSize: '11px',
                              fontWeight: 700,
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              color: 'var(--primary-blue)',
                              borderColor: 'rgba(2, 132, 199, 0.4)'
                            }}
                          >
                            <Edit2 size={12} />
                            <span>Edit Account</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => handleToggleUserStatus(user)}
                            className="btn btn-secondary"
                            style={{
                              padding: '6px 12px',
                              fontSize: '11px',
                              fontWeight: 700,
                              color: isDisabled ? 'var(--status-emerald-text)' : 'var(--status-rose-text)',
                              borderColor: isDisabled ? 'rgba(16, 185, 129, 0.4)' : 'rgba(239, 68, 68, 0.4)'
                            }}
                          >
                            {isDisabled ? 'Reactivate' : 'Disable'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                }))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Register / Edit Driver Modal */}
      {showAddModal && (
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
                  {editingDriver ? 'ड्राइवर विवरण बदलें (Edit Driver)' : 'नया ड्राइवर जोड़ें (Register New Driver)'}
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                  ड्राइवर का नाम, मोबाइल नंबर और लाइसेंस दर्ज करें
                </p>
              </div>
              <button
                onClick={() => setShowAddModal(false)}
                style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleDriverSubmit} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Full Name *
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Ramesh Kumar"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Phone Number *
                  </label>
                  <input
                    type="text"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+91 98210 00000"
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Commercial License *
                  </label>
                  <input
                    type="text"
                    required
                    value={licenseNumber}
                    onChange={(e) => setLicenseNumber(e.target.value)}
                    placeholder="DL-04-2020-001234"
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Assigned Vehicle
                  </label>
                  <select
                    value={assignedVehicleId}
                    onChange={(e) => setAssignedVehicleId(e.target.value)}
                    className="form-control"
                  >
                    <option value="">Unassigned</option>
                    {vehicles.map(v => (
                      <option key={v.id} value={v.id}>
                        {v.registrationNumber} ({v.model})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Emergency Contact
                  </label>
                  <input
                    type="text"
                    value={emergencyContact}
                    onChange={(e) => setEmergencyContact(e.target.value)}
                    placeholder="Kin Name (+91...)"
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                >
                  {editingDriver ? 'Save Changes' : 'Register Driver'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create User Account Modal */}
      {showAddAccountModal && (
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
                  नया ड्राइवर लॉगिन बनाएं (Create Driver Account)
                </h3>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                  मोबाइल ऐप में लॉगिन करने के लिए ईमेल और पासवर्ड सेट करें
                </p>
              </div>
              <button
                onClick={() => setShowAddAccountModal(false)}
                style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleCreateAccountSubmit} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {accountError && (
                <div style={{
                  background: 'var(--status-rose-light)',
                  border: '1px solid rgba(239, 68, 68, 0.3)',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  color: 'var(--status-rose-text)',
                  fontSize: '12px',
                  fontWeight: 600
                }}>
                  {accountError}
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Driver Name *
                </label>
                <input
                  type="text"
                  required
                  value={accountFormData.name}
                  onChange={(e) => setAccountFormData({ ...accountFormData, name: e.target.value })}
                  placeholder="Driver Full Name"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Login Email *
                  </label>
                  <input
                    type="email"
                    required
                    value={accountFormData.email}
                    onChange={(e) => setAccountFormData({ ...accountFormData, email: e.target.value })}
                    placeholder="driver@fleetroute.com"
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Phone Number
                  </label>
                  <input
                    type="text"
                    value={accountFormData.phone}
                    onChange={(e) => setAccountFormData({ ...accountFormData, phone: e.target.value })}
                    placeholder="+91..."
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Initial Password *
                  </label>
                  <input
                    type="text"
                    required
                    value={accountFormData.password}
                    onChange={(e) => setAccountFormData({ ...accountFormData, password: e.target.value })}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Link to Driver Profile
                  </label>
                  <select
                    value={accountFormData.driverId}
                    onChange={(e) => setAccountFormData({ ...accountFormData, driverId: e.target.value })}
                    className="form-control"
                  >
                    <option value="">Select driver...</option>
                    {drivers.map(d => (
                      <option key={d.id} value={d.id}>{d.name} ({d.id})</option>
                    ))}
                  </select>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  onClick={() => setShowAddAccountModal(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                >
                  Create Account
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Driver User Account Modal */}
      {showEditAccountModal && editingAccount && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(15, 23, 42, 0.6)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1300,
          padding: '16px'
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            width: '100%',
            maxWidth: '520px',
            boxShadow: 'var(--shadow-modal)',
            border: '1px solid var(--slate-200)',
            overflow: 'hidden'
          }}>
            <div style={{
              padding: '16px 20px',
              borderBottom: '1px solid var(--slate-200)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              background: 'var(--slate-50)'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Edit2 size={18} color="var(--primary-blue)" />
                <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>
                  एडिट ड्राइवर लॉगिन (Edit Driver Credentials)
                </h3>
              </div>
              <button
                type="button"
                onClick={() => {
                  setShowEditAccountModal(false);
                  setEditingAccount(null);
                }}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--slate-400)' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleEditAccountSubmit} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {accountError && (
                <div style={{ padding: '8px 12px', borderRadius: '8px', background: 'var(--status-rose-light)', color: 'var(--status-rose-text)', fontSize: '12px' }}>
                  {accountError}
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Driver Name *
                </label>
                <input
                  type="text"
                  required
                  value={editAccountFormData.name}
                  onChange={(e) => setEditAccountFormData({ ...editAccountFormData, name: e.target.value })}
                  placeholder="Driver Full Name"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Login Email *
                  </label>
                  <input
                    type="email"
                    required
                    value={editAccountFormData.email}
                    onChange={(e) => setEditAccountFormData({ ...editAccountFormData, email: e.target.value })}
                    placeholder="driver@fleetroute.com"
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Phone Number
                  </label>
                  <input
                    type="text"
                    value={editAccountFormData.phone}
                    onChange={(e) => setEditAccountFormData({ ...editAccountFormData, phone: e.target.value })}
                    placeholder="+91..."
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Reset Password (Optional)
                  </label>
                  <input
                    type="text"
                    value={editAccountFormData.password}
                    onChange={(e) => setEditAccountFormData({ ...editAccountFormData, password: e.target.value })}
                    placeholder="Leave blank to keep current"
                    className="form-control"
                  />
                  <div style={{ fontSize: '10px', color: 'var(--slate-400)', marginTop: '2px' }}>
                    Only fill if resetting driver's password
                  </div>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Link to Driver Profile
                  </label>
                  <select
                    value={editAccountFormData.driverId}
                    onChange={(e) => setEditAccountFormData({ ...editAccountFormData, driverId: e.target.value })}
                    className="form-control"
                  >
                    <option value="">Unlinked / Select driver...</option>
                    {drivers.map(d => (
                      <option key={d.id} value={d.id}>{d.name} ({d.id})</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Account Status
                </label>
                <select
                  value={editAccountFormData.status}
                  onChange={(e) => setEditAccountFormData({ ...editAccountFormData, status: e.target.value })}
                  className="form-control"
                >
                  <option value="active">Active (Can log into Driver App)</option>
                  <option value="disabled">Disabled (Blocked from logging in)</option>
                </select>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  onClick={() => {
                    setShowEditAccountModal(false);
                    setEditingAccount(null);
                  }}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
