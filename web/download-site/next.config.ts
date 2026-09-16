import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  async redirects() {
    return [
      { source: '/versions', destination: '/versiones', permanent: true },
      { source: '/versions/:version', destination: '/versiones/:version', permanent: true },
    ];
  },
};

export default nextConfig;
