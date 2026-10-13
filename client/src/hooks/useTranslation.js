// client/src/hooks/useTranslation.js
import { useState, useEffect, useCallback } from 'react';
import { getCurrentLanguage, setCurrentLanguage, t, SUPPORTED_LANGUAGES } from '../utils/i18n';

export function useTranslation() {
  const [lang, setLang] = useState(getCurrentLanguage());
  const [isLanguageChosen, setIsLanguageChosen] = useState(() => {
    if (typeof window !== 'undefined') {
      return Boolean(localStorage.getItem('fleetroute_lang_chosen'));
    }
    return true;
  });

  useEffect(() => {
    const handleLangChange = () => {
      setLang(getCurrentLanguage());
      setIsLanguageChosen(Boolean(localStorage.getItem('fleetroute_lang_chosen')));
    };

    window.addEventListener('fleetroute_lang_changed', handleLangChange);
    return () => {
      window.removeEventListener('fleetroute_lang_changed', handleLangChange);
    };
  }, []);

  const changeLanguage = useCallback((langCode) => {
    setCurrentLanguage(langCode);
    if (typeof window !== 'undefined') {
      localStorage.setItem('fleetroute_lang_chosen', 'true');
    }
    setLang(langCode);
    setIsLanguageChosen(true);
  }, []);

  const translate = useCallback((key, params = {}) => {
    return t(key, lang, params);
  }, [lang]);

  return {
    lang,
    t: translate,
    setLanguage: changeLanguage,
    isLanguageChosen,
    supportedLanguages: SUPPORTED_LANGUAGES
  };
}

export default useTranslation;
