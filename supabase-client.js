'use strict';

if (!window.supabase?.createClient) {
  throw new Error('Supabase client library did not load.');
}

window.tramviorSupabase = window.supabase.createClient(
  'https://octlxgzzuarymfupwhxy.supabase.co',
  'sb_publishable_ZcBxla62otYQl3cnY18Lag_uCrAxys5',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storage: window.sessionStorage
    }
  }
);
