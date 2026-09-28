<script setup lang="ts">
import FlipWords from './ui/flip-words/FlipWords.vue';

// import SparklesText from './ui/sparkles-text/SparklesText.vue';

// interface SparkleProps {
//   text?: string;
//   sparklesCount?: number;
//   colors?: {
//     first: string;
//     second: string;
//   };
// }

// const sparkleProps  = withDefaults(defineProps<SparkleProps>(), {
//   text: "plus efficacement",
//   sparklesCount: 10,
//   colors: () => ({ first: "#9e7aff", second: "#fe8bbb" }),

// });

interface Props {
    duration?: number;
}

const props = withDefaults(defineProps<Props>(), {
    duration: 3000,
});
</script>

<template>
    <div
        class="mx-auto mb-6 inline-flex items-center gap-2 rounded-full border bg-background/80 px-3 py-1 text-sm text-muted-foreground shadow-sm backdrop-blur">
        <span class="size-1.5 rounded-full bg-primary" />
        Votre CRM, simplement.
    </div>

    <h1 class="text-balance text-5xl font-bold tracking-tight sm:text-6xl lg:text-7xl">
        Gérez vos relations <p>Plus
            <FlipWords :words="['Efficacement', 'Rapidement']" :duration="props.duration"
                class="text-primary!" />
        </p>
    </h1>
</template>