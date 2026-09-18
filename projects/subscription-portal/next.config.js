/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produces a minimal .next/standalone build for the Docker image used
  // by the App Service container provisioned by projects/infra.
  output: 'standalone',
  reactStrictMode: true,
  eslint: {
    // Lint and format:check run as separate, fast CI steps before the Docker build so failures
    // surface quickly; running ESLint again inside the Docker build stage would be redundant.
    ignoreDuringBuilds: true,
  },
};

module.exports = nextConfig;
