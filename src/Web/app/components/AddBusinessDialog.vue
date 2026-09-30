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

async function logForm() {
    console.log(form.value);
}
</script>

<template>
    <Dialog>
        <DialogTrigger as-child>
            <Button variant="outline" class="w-full">
                <Plus />
                Add team
            </Button>
        </DialogTrigger>
        <DialogContent class="sm:max-w-106.25">
            <form @submit.prevent="logForm">

                <DialogHeader>
                    <DialogTitle>Create a new Business</DialogTitle>
                    <DialogDescription>
                        Add your other businesses to the same workspace
                    </DialogDescription>
                </DialogHeader>

                <div class="grid gap-4">
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

                <DialogFooter>
                    <DialogClose as-child>
                        <Button variant="outline" type="button">
                            Cancel
                        </Button>
                    </DialogClose>

                    <Button type="submit" >
                        Create Business
                    </Button>
                </DialogFooter>
            </form>
        </DialogContent>
    </Dialog>
</template>