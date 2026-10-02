<script setup lang="ts">
definePageMeta({
    public: true
})

const redirect = useRoute().query.redirect
</script>


<template>
    Access Denied
    <NuxtLink :to="``+redirect">
        <Button>
            Go Back
        </Button>
    </NuxtLink>
</template>