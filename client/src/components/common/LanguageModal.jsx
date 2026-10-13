import React, { useState } from 'react';
import { Languages, Check, X } from 'lucide-react';
import { SUPPORTED_LANGUAGES, t } from '../../utils/i18n';
import { soundEffects } from '../../utils/soundEffects';

export default function LanguageModal({
  isOpen,
  onClose,
  currentLanguage,
  onSelectLanguage,
  isFirstUse = false
}) {
  const [selected, setSelected] = useState(currentLanguage || 'hi');

  if (!isOpen) return null;

  const handleSelect = (code) => {
    setSelected(code);
    soundEffects.playActionClick();
  };

  const handleConfirm = () => {
    onSelectLanguage(selected);
    soundEffects.playSuccessChime();
    if (onClose) onClose();
  };

  return (
    <div 
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(15, 23, 42, 0.75)',
        backdropFilter: 'blur(6px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '16px',
        zIndex: 99999
      }}
      role="dialog"
      aria-modal="true"
      aria-labelledby="lang-modal-title"
    >
      <div 
        style={{
          background: '#ffffff',
          borderRadius: '24px',
          width: '100%',
          maxWidth: '440px',
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.4)',
          overflow: 'hidden',
          border: '2px solid var(--slate-200)',
          animation: 'fadeIn 0.2s ease-out'
        }}
      >
        {/* Header */}
        <div style={{
          background: '#ffffff',
          color: 'var(--navy-900)',
          padding: '24px 20px',
          textAlign: 'center',
          position: 'relative',
          borderBottom: '1px solid var(--slate-100)'
        }}>
          {!isFirstUse && onClose && (
            <button
              onClick={onClose}
              aria-label="Close language selector"
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                background: 'var(--slate-100)',
                border: 'none',
                color: 'var(--slate-400)',
                width: '36px',
                height: '36px',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer'
              }}
            >
              <X size={20} />
            </button>
          )}

          <div style={{
            width: '52px',
            height: '52px',
            borderRadius: '16px',
            background: 'linear-gradient(135deg, #0284c7 0%, #0d9488 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 12px',
            boxShadow: '0 4px 12px rgba(2, 132, 199, 0.35)'
          }}>
            <Languages size={28} color="#ffffff" />
          </div>

          <h2 id="lang-modal-title" style={{ fontSize: '20px', fontWeight: 800, margin: 0, color: 'var(--navy-900)' }}>
            {selected === 'hi' ? 'भाषा चुनें' : selected === 'gu' ? 'ભાષા પસંદ કરો' : 'Choose Language'}
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '6px', marginBottom: 0 }}>
            {selected === 'hi' 
              ? 'अपनी पसंदीदा भाषा चुनें' 
              : selected === 'gu' 
              ? 'તમારી અનુકૂળ ભાષા પસંદ કરો' 
              : 'Select your preferred language to continue'}
          </p>
        </div>

        {/* 3 Large Language Cards */}
        <div style={{ padding: '24px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          {SUPPORTED_LANGUAGES.map((lang) => {
            const isChosen = selected === lang.code;
            return (
              <button
                key={lang.code}
                onClick={() => handleSelect(lang.code)}
                style={{
                  minHeight: '64px',
                  padding: '16px 20px',
                  borderRadius: '16px',
                  border: isChosen ? '2.5px solid var(--primary-blue)' : '2px solid var(--slate-200)',
                  background: isChosen ? 'var(--sky-blue-light)' : '#ffffff',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  textAlign: 'left',
                  transition: 'all 0.15s ease',
                  boxShadow: isChosen ? '0 4px 14px rgba(2, 132, 199, 0.2)' : '0 2px 4px rgba(0, 0, 0, 0.04)'
                }}
              >
                <div style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{
                    fontSize: '22px',
                    fontWeight: 800,
                    color: isChosen ? 'var(--primary-blue)' : 'var(--navy-800)',
                    lineHeight: '1.2'
                  }}>
                    {lang.native}
                  </span>
                  <span style={{ fontSize: '13px', color: 'var(--slate-500)', fontWeight: 600, marginTop: '2px' }}>
                    {lang.label}
                  </span>
                </div>

                <div style={{
                  width: '32px',
                  height: '32px',
                  borderRadius: '50%',
                  background: isChosen ? 'var(--primary-blue)' : 'var(--slate-100)',
                  color: isChosen ? '#ffffff' : 'transparent',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  border: `2px solid ${isChosen ? 'var(--primary-blue)' : 'var(--slate-300)'}`,
                  flexShrink: 0
                }}>
                  <Check size={18} strokeWidth={3} />
                </div>
              </button>
            );
          })}

          {/* Confirm Button */}
          <button
            onClick={handleConfirm}
            style={{
              height: '58px',
              marginTop: '10px',
              borderRadius: '14px',
              background: 'linear-gradient(135deg, #0284c7 0%, #0d9488 100%)',
              color: '#ffffff',
              border: 'none',
              fontSize: '17px',
              fontWeight: 800,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px',
              boxShadow: '0 4px 16px rgba(2, 132, 199, 0.35)'
            }}
          >
            <span>{t('save', selected)}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
