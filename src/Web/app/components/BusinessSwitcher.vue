<script setup lang="ts">
import type { Component } from "vue"

import { ChevronsUpDown, Plus } from "@lucide/vue"
import { ref } from "vue"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"
import type { BusinessInfo, BusinessInfosResult } from "~~/shared/types/business"
import { toast } from "vue-sonner"
import AddBusinessDialog from "./AddBusinessDialog.vue"
const activeBusiness = ref<BusinessInfo>()
const businessInfos = ref<BusinessInfosResult>(null!)
async function fetchBusinesses() {
  try {
    const result = await $fetch<BusinessInfosResult>("/api/backend/business", {
      method: 'GET'
    });
    businessInfos.value = result
    activeBusiness.value = result.infos.at(0);
    return toast.success("Fetched businesses")

  } catch (error) {
    return toast.error("Error fetching businesses")
  }
}
const { isMobile } = useSidebar()
onMounted(() => {
  fetchBusinesses();
})
</script>

<template>
  <SidebarMenu>
    <SidebarMenuItem>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <SidebarMenuButton size="lg"
            class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground">
            <div
              class="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
              <component :is="activeBusiness?.businessName" class="size-4" />
            </div>
            <div class="grid flex-1 text-left text-sm leading-tight">
              <span class="truncate font-medium">
                {{ activeBusiness?.businessName }}
              </span>
              <span class="truncate text-xs">{{ activeBusiness?.membershipCount }} members</span>
            </div>
            <ChevronsUpDown class="ml-auto" />
          </SidebarMenuButton>
        </DropdownMenuTrigger>
        <DropdownMenuContent class="w-(--reka-dropdown-menu-trigger-width) min-w-56 rounded-lg" align="start"
          :side="isMobile ? 'bottom' : 'right'" :side-offset="4">
          <DropdownMenuLabel class="text-xs text-muted-foreground">
            Teams
          </DropdownMenuLabel>
          <DropdownMenuItem v-for="(businessInfo, index) in businessInfos.infos" :key="businessInfo.id" class="gap-2 p-2"
            @click="activeBusiness = businessInfo">
            <div class="flex size-6 items-center justify-center rounded-sm border">
              <!-- <component :is="businessInfo.id" class="size-3.5 shrink-0" /> -->
            </div>
            {{ businessInfo.businessName }}
            <DropdownMenuShortcut>⌘{{ index + 1 }}</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <!-- <DropdownMenuItem> -->
            <AddBusinessDialog />
          <!-- </DropdownMenuItem> -->
        </DropdownMenuContent>
      </DropdownMenu>
    </SidebarMenuItem>
  </SidebarMenu>
</template>
