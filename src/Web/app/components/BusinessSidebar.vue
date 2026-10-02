<script setup lang="ts">
import type { SidebarProps } from "@/components/ui/sidebar"

import {
  AudioWaveform,
  BookOpen,
  BuildingComplex,
  Command,
  Contact,
  GalleryVerticalEnd,
  Home,
  Settings2,
} from "@lucide/vue"
import NavMain from "@/components/NavMain.vue"
import NavUser from "@/components/NavUser.vue"
import BusinessSwitcher from "@/components/BusinessSwitcher.vue"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar"

const props = withDefaults(defineProps<SidebarProps>(), {
  collapsible: "icon",
})

// This is sample data.
const data = {
  teams: [
    {
      name: "Acme Inc",
      logo: GalleryVerticalEnd,
      plan: "Enterprise",
    },
    {
      name: "Acme Corp.",
      logo: AudioWaveform,
      plan: "Startup",
    },
    {
      name: "Evil Corp.",
      logo: Command,
      plan: "Free",
    },
  ],
  navMain: [
     {
      title: "Dashboard",
      url: "/business/dashboard",
      icon: Home,
    },
    {
      title: "Client",
      url: "/client/dashboard",
      icon: BuildingComplex,
    },
    {
      title: "Contacts",
      url: "#",
      icon: Contact,
      
    },
    {
      title: "Opportunities",
      url: "#",
      icon: BookOpen,
    },
    {
      title: "Staff",
      url: "#",
      icon: Settings2,
    },
  ],
}
</script>

<template>
  <Sidebar v-bind="props">
    <SidebarHeader>
      <BusinessSwitcher  />
    </SidebarHeader>
    <SidebarContent>
      <NavMain :items="data.navMain" />
      <!-- <NavProjects :projects="data.projects" /> -->
    </SidebarContent>
    <SidebarFooter>
      <NavUser />
    </SidebarFooter>
    <SidebarRail />
  </Sidebar>
</template>
