export function getErrorMessage(err: any): string {
    const issues =
        err?.data?.data?.issues ??
        err?.data?.issues ??
        err?.data?.errors

    if (Array.isArray(issues) && issues.length > 0) {
        const firstIssue = issues[0]

        if (typeof firstIssue?.message === "string") {
            return firstIssue.message
        }

        if (typeof firstIssue === "string") {
            return firstIssue
        }
    }

    // H3-wrapped error
    const message = err?.data?.message

    if (typeof message === "string" && message.trim()) {
        // Handle APIs that put a JSON array inside message
        if (message.trimStart().startsWith("[")) {
            try {
                const parsed = JSON.parse(message)

                if (Array.isArray(parsed) && parsed[0]?.message) {
                    return parsed[0].message
                }
            } catch {
                // Not JSON — use the message directly
            }
        }

        return message
    }

    // Raw ASP.NET ProblemDetails
    const detail =
        err?.data?.detail ??
        err?.response?._data?.detail

    if (typeof detail === "string" && detail.trim()) {
        return detail
    }

    // Other possible API error formats
    const title =
        err?.data?.title ??
        err?.response?._data?.title

    if (typeof title === "string" && title.trim()) {
        return title
    }

    return "Une erreur est survenue."
}