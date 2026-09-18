/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produces a minimal .next/standalone build for the Docker image used
  // by the App Service container in the terraform-poc-gha-oidc setup.
  output: 'standalone',
  reactStrictMode: true,
};

module.exports = nextConfig;
