import type { Config } from 'tailwindcss';

export default {
  content: ['./app/**/*.{js,ts,jsx,tsx}', './components/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#151124', panel: '#201a31', line: '#302842', mint: '#2fc8b3', gold: '#f4b844', coral: '#ff6b5d', muted: '#9990ad', cream: '#fff2d8'
      },
      boxShadow: { panel: '0 18px 45px rgba(7, 5, 14, .22)' },
      borderRadius: { '4xl': '2rem' }
    }
  },
  plugins: [],
} satisfies Config;
