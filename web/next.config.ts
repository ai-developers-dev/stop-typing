import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  typescript: {
    // Convex _generated types are created by `npx convex dev`.
    // Skip type checking in build until Convex project is initialized.
    ignoreBuildErrors: true,
  },
};

export default nextConfig;
