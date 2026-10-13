import React from 'react';
import { AlertTriangle, RotateCcw } from 'lucide-react';

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary caught an unhandled error:', error, errorInfo);
    this.setState({ errorInfo });
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null, errorInfo: null });
    if (this.props.onReset) {
      this.props.onReset();
    }
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          padding: '24px',
          margin: '16px',
          background: '#ffffff',
          borderRadius: '12px',
          border: '1px solid #fecdd3',
          boxShadow: '0 4px 16px rgba(225, 29, 72, 0.08)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          gap: '14px'
        }}>
          <div style={{
            width: '44px',
            height: '44px',
            borderRadius: '50%',
            background: '#ffe4e6',
            color: '#e11d48',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <AlertTriangle size={24} />
          </div>

          <div>
            <h3 style={{ fontSize: '16px', fontWeight: 800, color: '#1e293b', marginBottom: '4px' }}>
              {this.props.fallbackTitle || 'Component encountered an issue'}
            </h3>
            <p style={{ fontSize: '12px', color: '#64748b', maxWidth: '420px', margin: '0 auto' }}>
              {this.state.error?.message || 'An unexpected rendering error occurred. Please refresh or reset to continue.'}
            </p>
          </div>

          <button
            type="button"
            onClick={this.handleReset}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 16px',
              borderRadius: '8px',
              background: '#0284c7',
              color: '#ffffff',
              border: 'none',
              fontWeight: 700,
              fontSize: '12px',
              cursor: 'pointer'
            }}
          >
            <RotateCcw size={13} />
            <span>Reset &amp; Try Again</span>
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
