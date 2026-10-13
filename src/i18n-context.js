import { createContext } from 'react';

// Keep the context identity stable when translation components refresh in development.
export default createContext(null);
