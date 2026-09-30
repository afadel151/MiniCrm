<script setup lang="ts">
import type { UserDto } from '~~/shared/auth/auth.dto'

const props = defineProps<{ role?: 'client' | 'business' }>()
const emit = defineEmits<{
    (e: 'success', user: UserDto): void
    (e: 'error', message: string): void
    (e: 'register'): void
}>()

const config = useRuntimeConfig()
const { fetch: refreshClientSession } = useUserSession()

declare global { interface Window { google?: any } }

const businessName = ref('')
let pendingCredential: string | null = null
let scriptPromise: Promise<void> | null = null

function loadGoogleScript(): Promise<void> {
    if (window.google?.accounts?.id) return Promise.resolve()
    scriptPromise ??= new Promise((resolve, reject) => {
        const s = document.createElement('script')
        s.src = 'https://accounts.google.com/gsi/client'
        s.async = true
        s.onload = () => resolve()
        s.onerror = () => { scriptPromise = null; reject(new Error('Google script failed to load')) }
        document.head.appendChild(s)
    })
    return scriptPromise
}

async function sendToBackend(idToken: string) {
    console.log(1)// 1
    console.log({
        method: 'POST',
        body: {
            idToken,
            role: props.role === 'business' ? "Business" : props.role === 'client' ? 'Client' : "",
        },
    })
    const user = await $fetch<{ user: UserDto }>('/api/auth/google', {
        method: 'POST',
        body: {
            idToken,
            role: props.role === 'business' ? "Business" : props.role === 'client' ? 'Client' : "",
        },
    });
    console.log(2)
    return user;
}

async function onCredentialResponse(response: any) {
    pendingCredential = response.credential
    try {
        const res = await sendToBackend(response.credential)
        console.log(2);
        await refreshClientSession()
        emit('success', res.user)
    } catch (err: any) {
        console.log(3); // 3
        console.log(err.data.data.code); // 3

        if(err.data?.data.code === 'redirect-to-register') {
            emit('register');
        }
        emit('error', err.data?.data.message ?? 'Google sign-in failed.')
    }
}

async function retryWithBusinessName() {
    if (!pendingCredential) return
    try {
        console.log(4);

        const res = await sendToBackend(pendingCredential)
        await refreshClientSession()
        emit('success', res.user)
    } catch (err: any) {
        console.log(5);

        emit('error', err.data?.message ?? 'Google sign-in failed.')
    }
}
let googleInitialized = false
async function renderButton(el: HTMLElement) {
    console.log('Google Client ID:', config.public.googleClientId)
    console.log('Origin:', window.location.origin)
    try {
        await loadGoogleScript()
        if (!googleInitialized) {
            window.google.accounts.id.initialize({
                client_id: config.public.googleClientId as string,
                callback: onCredentialResponse,
            })

            googleInitialized = true
        }
        window.google.accounts.id.renderButton(el, {
            type: 'standard', theme: 'outline', size: 'large',
            text: props.role ? 'signup_with' : 'signin_with',
            width: 320,
        })
    } catch (err: any) {
        emit('error', err.message ?? 'Google sign-in unavailable')
    }
}

const buttonEl = ref<HTMLElement | null>(null)
onMounted(() => { if (buttonEl.value) renderButton(buttonEl.value) })
</script>

<template>

    <div  ref="buttonEl" class="flex justify-center" />
</template>