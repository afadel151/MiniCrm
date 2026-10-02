export function useWorkspace() {
  const businesses = useState<BusinessInfo[]>(
    "workspace-businesses",
    () => []
  )

  const activeBusinessId = useCookie<number | null>(
    "active-business-id",
    {
      default: () => null,
      sameSite: "lax"
    }
  )

  const initialized = useState(
    "workspace-initialized",
    () => false
  )

  async function initialize() {
    if (initialized.value) {
      return
    }

    const result = await $fetch<BusinessInfosResult>(
      "/api/backend/business"
    )

    businesses.value = result.infos

    // Restore previous workspace if it still exists
    const exists = businesses.value.some(
      business => business.id === activeBusinessId.value
    )

    if (!exists) {
      activeBusinessId.value =
        businesses.value[0]?.id ?? null
    }

    initialized.value = true
  }

  const activeBusiness = computed(() =>
    businesses.value.find(
      business => business.id === activeBusinessId.value
    )
  )

  function selectBusiness(id: number) {
    if (businesses.value.some(b => b.id === id)) {
      activeBusinessId.value = id
    }
  }
  function addBusiness(info : BusinessInfo)
  {
    businesses.value.push(info)
  }

  return {
    businesses,
    activeBusiness,
    activeBusinessId,
    initialized,
    initialize,
    selectBusiness,
    addBusiness
  }
}