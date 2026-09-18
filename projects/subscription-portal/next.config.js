/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produces a minimal .next/standalone build for the Docker image used
  // by the App Service container provisioned by projects/infra.
  output: 'standalone',
  reactStrictMode: true,
};

module.exports = nextConfig;
