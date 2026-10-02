<script setup lang="ts">

import { ChevronsUpDown, Plus, Building2 } from "@lucide/vue"
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
const {
  businesses,
  activeBusiness,
  initialize,
  selectBusiness,
  addBusiness
} = useWorkspace()

onMounted(() => {
  initialize()
})
const { isMobile } = useSidebar();
function createdBusiness(infos: BusinessInfo) {
  addBusiness(infos);
}
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
              <Building2 class="size-4" />
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
          <DropdownMenuItem v-for="(business, index) in businesses" :key="business.id" class="gap-2 p-2"
            @click="selectBusiness(business.id)">
            <div class="flex size-6 items-center justify-center rounded-sm border">
              <!-- <component :is="businessInfo.id" class="size-3.5 shrink-0" /> -->
            </div>
            {{ business.businessName }}
            <DropdownMenuShortcut>⌘{{ index + 1 }}</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <!-- <DropdownMenuItem> -->
          <AddBusinessDialog @success="createdBusiness" />
          <!-- </DropdownMenuItem> -->
        </DropdownMenuContent>
      </DropdownMenu>
    </SidebarMenuItem>
  </SidebarMenu>
</template>
