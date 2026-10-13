import React, { useState, useEffect } from 'react';
import { 
  FileCheck, 
  Search, 
  Calendar, 
  Camera, 
  PenTool, 
  User, 
  Phone, 
  Boxes, 
  AlertTriangle, 
  CheckCircle2, 
  Truck,
  ExternalLink,
  Filter
} from 'lucide-react';
import { api } from '../../utils/api';

export default function DeliveriesView() {
  const [proofs, setProofs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const loadProofs = async () => {
    try {
      setLoading(true);
      const data = await api.getDeliveryProofs();
      setProofs(data);
    } catch (err) {
      console.error('Failed to load delivery proofs:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProofs();
  }, []);

  const filteredProofs = proofs.filter(p => {
    const q = searchTerm.toLowerCase();
    const matchesSearch = 
      (p.recipientName && p.recipientName.toLowerCase().includes(q)) ||
      (p.tripId && p.tripId.toLowerCase().includes(q)) ||
      (p.notes && p.notes.toLowerCase().includes(q)) ||
      (p.driverId && p.driverId.toLowerCase().includes(q));

    const hasDamage = (p.damagedQty && p.damagedQty > 0) || (p.rejectedQty && p.rejectedQty > 0);
    const matchesStatus = 
      statusFilter === 'all' || 
      (statusFilter === 'clean' && !hasDamage) || 
      (statusFilter === 'exceptions' && hasDamage);

    return matchesSearch && matchesStatus;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div>
        <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
          Deliveries &amp; Proof of Delivery (POD) Records
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
          Audited delivery confirmations, signatory verification, received quantities, and damaged/rejected exception ledgers.
        </p>
      </div>

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
            placeholder="Search by recipient, trip ID, or notes..."
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
          <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontWeight: 600 }}>Filter:</span>
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
            <option value="all">All Deliveries ({proofs.length})</option>
            <option value="clean">Clean Drops (100% Accepted)</option>
            <option value="exceptions">Discrepancies / Damaged</option>
          </select>
        </div>
      </div>

      {/* Proof of Delivery Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: '16px' }}>
        {filteredProofs.length === 0 ? (
          <div style={{
            gridColumn: '1 / -1',
            background: '#ffffff',
            borderRadius: '12px',
            padding: '40px',
            textAlign: 'center',
            color: 'var(--slate-400)',
            border: '1px solid var(--slate-200)'
          }}>
            No delivery proof records found.
          </div>
        ) : (
          filteredProofs.map((pod, idx) => {
            const hasDamage = (pod.damagedQty && pod.damagedQty > 0) || (pod.rejectedQty && pod.rejectedQty > 0);
            return (
              <div
                key={pod.id || idx}
                style={{
                  background: '#ffffff',
                  borderRadius: '14px',
                  padding: '18px',
                  border: `1px solid ${hasDamage ? 'rgba(239, 68, 68, 0.3)' : 'var(--slate-200)'}`,
                  boxShadow: 'var(--shadow-card)',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px'
                }}
              >
                {/* Header */}
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
                  <div>
                    <span style={{
                      fontSize: '11px',
                      fontWeight: 800,
                      color: 'var(--primary-blue)',
                      fontFamily: 'var(--font-mono)'
                    }}>
                      {pod.tripId}
                    </span>
                    <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)', marginTop: '2px' }}>
                      {pod.recipientName || 'Authorized Signatory'}
                    </h3>
                  </div>

                  <span style={{
                    fontSize: '10px',
                    fontWeight: 800,
                    padding: '3px 8px',
                    borderRadius: '9999px',
                    textTransform: 'uppercase',
                    background: hasDamage ? 'var(--status-rose-light)' : 'var(--status-emerald-light)',
                    color: hasDamage ? 'var(--status-rose-text)' : 'var(--status-emerald-text)',
                    border: `1px solid ${hasDamage ? 'rgba(239, 68, 68, 0.3)' : 'rgba(16, 185, 129, 0.3)'}`
                  }}>
                    {hasDamage ? 'Exception Logged' : 'Verified Delivery'}
                  </span>
                </div>

                {/* Quantities summary banner */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr 1fr',
                  gap: '6px',
                  background: 'var(--slate-50)',
                  padding: '10px',
                  borderRadius: '10px',
                  border: '1px solid var(--slate-200)',
                  textAlign: 'center'
                }}>
                  <div>
                    <div style={{ fontSize: '10px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>
                      Delivered
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 800, color: 'var(--status-emerald)' }}>
                      {pod.deliveredQty ?? 'N/A'}
                    </div>
                  </div>

                  <div>
                    <div style={{ fontSize: '10px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>
                      Damaged
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 800, color: pod.damagedQty > 0 ? 'var(--status-rose)' : 'var(--slate-400)' }}>
                      {pod.damagedQty || 0}
                    </div>
                  </div>

                  <div>
                    <div style={{ fontSize: '10px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>
                      Rejected
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 800, color: pod.rejectedQty > 0 ? 'var(--status-amber)' : 'var(--slate-400)' }}>
                      {pod.rejectedQty || 0}
                    </div>
                  </div>
                </div>

                {/* Evidence Details */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '12px', color: 'var(--slate-600)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Calendar size={13} color="var(--slate-400)" />
                    <span>{pod.timestamp ? new Date(pod.timestamp).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) : 'Verified at stop'}</span>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <PenTool size={13} color="var(--primary-blue)" />
                    <span>Signature Note: <strong>{pod.signature || 'Signatory verified onsite'}</strong></span>
                  </div>

                  {pod.hasPhoto && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--primary-teal)', fontWeight: 600 }}>
                      <Camera size={13} />
                      <span>Delivery photo captured &amp; stored</span>
                    </div>
                  )}

                  {pod.notes && (
                    <div style={{ background: 'var(--sky-blue-light)', padding: '6px 10px', borderRadius: '6px', fontSize: '11px', color: 'var(--navy-800)', marginTop: '2px' }}>
                      Remarks: {pod.notes}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

    </div>
  );
}
