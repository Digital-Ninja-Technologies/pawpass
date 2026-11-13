/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ["@pawpass/shared"],
  // Course cover pictures are uploaded through a server action (up to 5 MB, plus the form).
  experimental: { serverActions: { bodySizeLimit: "6mb" } },
};
export default nextConfig;
