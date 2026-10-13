import React, { useState, useEffect } from 'react';
import { 
  Package, 
  Plus, 
  Search, 
  Edit2, 
  Archive, 
  RotateCcw, 
  CheckCircle2, 
  AlertCircle, 
  Boxes, 
  Scale, 
  ShieldAlert,
  X
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

const PRODUCT_CATEGORIES = [
  { id: 'OFFICE_FURNITURE', label: 'Office Furniture' },
  { id: 'MASSAGE_CHAIRS', label: 'Massage Chairs & Wellness' },
  { id: 'RECLINER_CHAIRS', label: 'Recliners & Seating' },
  { id: 'ELECTRONICS', label: 'Electronics & Hardware' },
  { id: 'GENERAL_GOODS', label: 'General Commercial Freight' }
];

export default function ProductsManager() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [showArchived, setShowArchived] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    category: 'OFFICE_FURNITURE',
    defaultWeightKg: '15',
    unit: 'units',
    fragile: false,
    description: ''
  });
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const loadProducts = async () => {
    try {
      setLoading(true);
      const data = await api.getProducts();
      setProducts(data);
    } catch (err) {
      console.error('Failed to load products:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProducts();
  }, []);

  const handleOpenCreate = () => {
    setEditingProduct(null);
    setFormData({
      name: '',
      category: 'OFFICE_FURNITURE',
      defaultWeightKg: '15',
      unit: 'units',
      fragile: false,
      description: ''
    });
    setErrorMsg('');
    setShowModal(true);
  };

  const handleOpenEdit = (prod) => {
    setEditingProduct(prod);
    setFormData({
      name: prod.name,
      category: prod.category || 'OFFICE_FURNITURE',
      defaultWeightKg: String(prod.defaultWeightKg || prod.weightKg || '15'),
      unit: prod.unit || 'units',
      fragile: Boolean(prod.fragile),
      description: prod.description || ''
    });
    setErrorMsg('');
    setShowModal(true);
  };

  const handleSaveProduct = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    soundEffects.playActionClick();

    if (!formData.name.trim()) {
      setErrorMsg('Product name is required.');
      return;
    }

    try {
      if (editingProduct) {
        await api.updateProduct(editingProduct.id, {
          name: formData.name.trim(),
          category: formData.category,
          defaultWeightKg: parseFloat(formData.defaultWeightKg) || 10,
          unit: formData.unit,
          fragile: formData.fragile,
          description: formData.description
        });
        setSuccessMsg(`Product ${formData.name} updated successfully.`);
      } else {
        await api.createProduct({
          name: formData.name.trim(),
          category: formData.category,
          defaultWeightKg: parseFloat(formData.defaultWeightKg) || 10,
          unit: formData.unit,
          fragile: formData.fragile,
          description: formData.description
        });
        setSuccessMsg(`Product ${formData.name} created successfully.`);
      }

      soundEffects.playSuccessChime();
      setShowModal(false);
      await loadProducts();
      setTimeout(() => setSuccessMsg(''), 3000);
    } catch (err) {
      setErrorMsg(err.message || 'Failed to save product.');
    }
  };

  const handleArchiveToggle = async (prod) => {
    soundEffects.playActionClick();
    try {
      await api.archiveProduct(prod.id);
      soundEffects.playSuccessChime();
      await loadProducts();
    } catch (err) {
      console.error('Failed to archive product:', err);
    }
  };

  const filteredProducts = products.filter(p => {
    const matchesSearch = 
      p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (p.category && p.category.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (p.id && p.id.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCategory = categoryFilter === 'all' || p.category === categoryFilter;
    const matchesArchive = showArchived ? true : p.status !== 'archived';

    return matchesSearch && matchesCategory && matchesArchive;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Products &amp; Cargo Catalog
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Maintain product categories, handling instructions, unit weight ratings, and fragile designations.
          </p>
        </div>

        <button
          onClick={handleOpenCreate}
          className="btn btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
        >
          <Plus size={16} />
          Register New Product
        </button>
      </div>

      {successMsg && (
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
          <span>{successMsg}</span>
        </div>
      )}

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
        gap: '12px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: 1, minWidth: '240px' }}>
          <Search size={16} color="var(--slate-400)" />
          <input
            type="text"
            placeholder="Search by product name, category, or ID..."
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
            <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontWeight: 600 }}>Category:</span>
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
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
              <option value="all">All Categories</option>
              {PRODUCT_CATEGORIES.map(c => (
                <option key={c.id} value={c.id}>{c.label}</option>
              ))}
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

      {/* Products Table */}
      <div style={{
        background: '#ffffff',
        borderRadius: '12px',
        border: '1px solid var(--slate-200)',
        overflow: 'hidden',
        boxShadow: 'var(--shadow-card)'
      }}>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
            <thead>
              <tr style={{ background: 'var(--slate-50)', borderBottom: '1px solid var(--slate-200)', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                <th style={{ padding: '12px 16px' }}>Product &amp; ID</th>
                <th style={{ padding: '12px 16px' }}>Category</th>
                <th style={{ padding: '12px 16px' }}>Unit Weight (Rating)</th>
                <th style={{ padding: '12px 16px' }}>Packaging &amp; Fragile</th>
                <th style={{ padding: '12px 16px' }}>Status</th>
                <th style={{ padding: '12px 16px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredProducts.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ padding: '40px 16px', textAlign: 'center', color: 'var(--slate-400)' }}>
                    No products found matching criteria.
                  </td>
                </tr>
              ) : (
                filteredProducts.map(prod => {
                  const isArchived = prod.status === 'archived';
                  return (
                    <tr 
                      key={prod.id}
                      style={{ 
                        borderBottom: '1px solid var(--slate-100)',
                        background: isArchived ? 'var(--slate-50)' : '#ffffff',
                        opacity: isArchived ? 0.65 : 1
                      }}
                    >
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ fontWeight: 800, color: 'var(--navy-800)' }}>
                          {prod.name}
                        </div>
                        <div style={{ fontSize: '11px', color: 'var(--slate-400)', fontFamily: 'var(--font-mono)' }}>
                          {prod.id}
                        </div>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <span style={{
                          fontSize: '11px',
                          fontWeight: 700,
                          padding: '3px 8px',
                          borderRadius: '6px',
                          background: 'var(--sky-blue-light)',
                          color: 'var(--primary-blue)'
                        }}>
                          {(prod.category || 'GENERAL').replace('_', ' ')}
                        </span>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 700, color: 'var(--navy-800)' }}>
                          <Scale size={14} color="var(--primary-teal)" />
                          <span>{prod.defaultWeightKg || prod.weightKg || '10'} kg</span>
                        </div>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '12px', color: 'var(--slate-600)' }}>{prod.unit || 'units'}</span>
                          {prod.fragile && (
                            <span style={{
                              fontSize: '10px',
                              fontWeight: 800,
                              padding: '2px 6px',
                              borderRadius: '4px',
                              background: 'var(--status-amber-light)',
                              color: 'var(--status-amber-text)',
                              border: '1px solid rgba(245, 158, 11, 0.3)'
                            }}>
                              FRAGILE
                            </span>
                          )}
                        </div>
                      </td>

                      <td style={{ padding: '14px 16px' }}>
                        <span style={{
                          fontSize: '11px',
                          fontWeight: 700,
                          padding: '3px 8px',
                          borderRadius: '9999px',
                          textTransform: 'uppercase',
                          background: isArchived ? 'var(--slate-100)' : 'var(--status-emerald-light)',
                          color: isArchived ? 'var(--slate-500)' : 'var(--status-emerald-text)'
                        }}>
                          {isArchived ? 'Archived' : 'Active'}
                        </span>
                      </td>

                      <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '6px' }}>
                          <button
                            onClick={() => handleOpenEdit(prod)}
                            className="btn btn-secondary"
                            style={{ padding: '5px 8px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                          >
                            <Edit2 size={12} />
                            <span>Edit</span>
                          </button>

                          <button
                            onClick={() => handleArchiveToggle(prod)}
                            className="btn btn-secondary"
                            style={{ padding: '5px 8px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                            title={isArchived ? 'Restore Product' : 'Archive Product'}
                          >
                            {isArchived ? <RotateCcw size={12} color="var(--primary-teal)" /> : <Archive size={12} color="var(--status-rose)" />}
                            <span>{isArchived ? 'Restore' : 'Archive'}</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create / Edit Modal */}
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
              background: 'var(--navy-800)',
              color: '#ffffff',
              padding: '18px 20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Package size={18} color="var(--primary-blue)" />
                <h3 style={{ fontSize: '16px', fontWeight: 800 }}>
                  {editingProduct ? 'Edit Catalog Product' : 'Register New Product'}
                </h3>
              </div>
              <button
                onClick={() => setShowModal(false)}
                style={{ background: 'none', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveProduct} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {errorMsg && (
                <div style={{
                  background: 'var(--status-rose-light)',
                  border: '1px solid rgba(239, 68, 68, 0.3)',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  color: 'var(--status-rose-text)',
                  fontSize: '12px',
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px'
                }}>
                  <AlertCircle size={15} />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Product Name *
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. Ergonomic Office Mesh Chair"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Category
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="form-control"
                  >
                    {PRODUCT_CATEGORIES.map(c => (
                      <option key={c.id} value={c.id}>{c.label}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Unit Weight (kg)
                  </label>
                  <input
                    type="number"
                    step="0.5"
                    min="0"
                    value={formData.defaultWeightKg}
                    onChange={(e) => setFormData({ ...formData, defaultWeightKg: e.target.value })}
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    Packaging Unit
                  </label>
                  <select
                    value={formData.unit}
                    onChange={(e) => setFormData({ ...formData, unit: e.target.value })}
                    className="form-control"
                  >
                    <option value="units">Units</option>
                    <option value="boxes">Boxes</option>
                    <option value="pallets">Pallets</option>
                    <option value="crates">Crates</option>
                  </select>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', paddingTop: '20px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: 700, color: 'var(--navy-800)' }}>
                    <input
                      type="checkbox"
                      checked={formData.fragile}
                      onChange={(e) => setFormData({ ...formData, fragile: e.target.checked })}
                    />
                    <span>Mark as Fragile Cargo</span>
                  </label>
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Handling &amp; Storage Notes
                </label>
                <textarea
                  rows="2"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="e.g. Keep upright, do not stack more than 3 boxes high."
                  className="form-control"
                />
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
                  {editingProduct ? 'Save Changes' : 'Create Product'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
