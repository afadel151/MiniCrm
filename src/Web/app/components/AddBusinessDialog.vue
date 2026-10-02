<script setup lang="ts">
import { Button } from '@/components/ui/button'
import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Plus } from '@lucide/vue'
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select'
import { toast } from 'vue-sonner'
const emit = defineEmits<{
    (e: 'success', business: BusinessInfo): void
}>();

const form = ref<CreateBusinessDto>({
    businessName: '',
    description: '',
    businessDomain: BusinessDomain.Technology,
    businessAdress: '',
    website: '',
})

const businessDomains = Object.values(BusinessDomain)

const formatDomain = (domain: string) => {
    return domain.replace(/([A-Z])/g, ' $1').trim()
}

async function createBusiness() {
    try {
        const business = await $fetch<BusinessInfo>("/api/backend/business", {
            method: 'POST',
            body: form.value
        });
        if (!business) {
            toast.error("Business was created but no data was returned.")
            return
        }

        addBusinessOpen.value = false
        emit("success", business)

        toast.success(`${business.businessName} created successfully`)
    } catch (err) {
        toast.error(
            errorMessage(
                err,
                'Unable to create the business. Please try again.',
            ),
        )
    }
}
const addBusinessOpen = ref(false)

</script>

<template>
    <Dialog v-model:open="addBusinessOpen">
        <DialogTrigger as-child>
            <Button variant="ghost" class="w-full">
                <Plus />
                create a new business
            </Button>
        </DialogTrigger>
        <DialogContent class="sm:max-w-106.25">
            <form @submit.prevent="createBusiness">

                <DialogHeader>
                    <DialogTitle>Create a new Business</DialogTitle>
                    <DialogDescription>
                        Add your other businesses to the same workspace
                    </DialogDescription>
                </DialogHeader>

                <div class="grid gap-4 mt-5">
                    <!-- Business Name -->
                    <div class="grid gap-3">
                        <Label for="business-name">Name</Label>
                        <Input id="business-name" v-model="form.businessName" placeholder="Business name" />
                    </div>

                    <!-- Description -->
                    <div class="grid gap-3">
                        <Label for="business-description">Description</Label>
                        <Input id="business-description" v-model="form.description"
                            placeholder="Describe your business" />
                    </div>

                    <!-- Business Domain -->
                    <div class="grid gap-3">
                        <Label for="business-domain">Business Domain</Label>

                        <Select v-model="form.businessDomain">
                            <SelectTrigger id="business-domain" class="w-full">
                                <SelectValue placeholder="Select a business domain" />
                            </SelectTrigger>

                            <SelectContent>
                                <SelectItem v-for="domain in businessDomains" :key="domain" :value="domain">
                                    {{ formatDomain(domain) }}
                                </SelectItem>
                            </SelectContent>
                        </Select>
                    </div>

                    <!-- Address -->
                    <div class="grid gap-3">
                        <Label for="business-address">Address</Label>
                        <Input id="business-address" v-model="form.businessAdress" placeholder="Business address" />
                    </div>

                    <!-- Website -->
                    <div class="grid gap-3">
                        <Label for="business-website">Website</Label>
                        <Input id="business-website" v-model="form.website" placeholder="https://example.com" />
                    </div>
                </div>

                <DialogFooter class="mt-5">
                    <DialogClose as-child>
                        <Button variant="outline" type="button">
                            Cancel
                        </Button>
                    </DialogClose>
                    <Button type="submit">
                        Create Business
                    </Button>
                </DialogFooter>
            </form>
        </DialogContent>
    </Dialog>
</template>