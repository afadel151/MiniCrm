export function getErrorMessage(err: any): string {
  const issues = err?.data?.data?.issues ?? err?.data?.issues
  if (Array.isArray(issues) && issues[0]?.message) return issues[0].message

  const msg = err?.data?.message
  if (typeof msg === 'string' && msg.trimStart().startsWith('[')) {
    try {
      const parsed = JSON.parse(msg)
      if (Array.isArray(parsed) && parsed[0]?.message) return parsed[0].message
    } catch {
      // not JSON, fall through
    }
  }

  return typeof msg === 'string' && msg ? msg : 'Une erreur est survenue.'
}