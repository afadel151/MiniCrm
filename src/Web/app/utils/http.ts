export function errorStatus(e: any): number {
    return e?.response?.status ?? e?.statusCode ?? e?.status ?? 0
}

export function errorMessage(
    e: any,
    fallback = 'Something went wrong. Try again.',
): string {
    // Your Nitro error shape: { data: { message } }
    const message =
        e?.data?.data?.message ??
        e?.data?.message

    if (typeof message === 'string' && message.trim()) {
        return message
    }

    // ASP.NET ProblemDetails
    const detail =
        e?.data?.detail ??
        e?.response?._data?.detail

    if (typeof detail === 'string' && detail.trim()) {
        return detail
    }

    // ProblemDetails title
    const title =
        e?.data?.title ??
        e?.response?._data?.title

    if (typeof title === 'string' && title.trim()) {
        return title
    }

    if (
        typeof e?.statusMessage === 'string' &&
        e.statusMessage.trim()
    ) {
        return e.statusMessage
    }

    if (
        typeof e?.message === 'string' &&
        e.message.trim()
    ) {
        return e.message
    }

    return fallback
}