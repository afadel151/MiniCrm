import tailwindcss from "@tailwindcss/vite";

export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",
  devtools: { enabled: true },
  runtimeConfig: {
    apiBaseUrl: process.env.API_BASE_URL || "https://localhost:7056",
    public: {
      googleClientId: process.env.NUXT_PUBLIC_GOOGLE_CLIENT_ID,
    },
    session: {
      maxAge: 60 * 60,
      cookie: {
        sameSite: "strict",
        secure: true,
      },
      password: process.env.NUXT_SESSION_PASSWORD
    },
  },
  css: ["~/assets/css/tailwind.css"],
  vite: {
    plugins: [tailwindcss()],
  },
  modules: ["shadcn-nuxt", "nuxt-auth-utils"],
  shadcn: {
    /**
     * Prefix for all the imported component.
     * @default "Ui"
     */
    prefix: "",
    /**
     * Directory that the component lives in.
     * Will respect the Nuxt aliases.
     * @link https://nuxt.com/docs/api/nuxt-config#alias
     * @default "@/components/ui"
     */
    componentDir: "@/components/ui",
  }
});
