// app/utils/invitation.ts  (auto-imported)

/** Same rule as the API's Mask(): first character, ***, then the domain. Used only to hint, the server decides. */
export function maskEmail(email: string): string {
  const at = email.indexOf('@')
  return at < 1 ? '***' : `${email[0]}***${email.slice(at)}`
}

/** "a staff member" reads naturally in a sentence. Used in "invited you to join the team as ...". */
export function roleInSentence(role: string): string {
  return role === 'Manager' ? 'a manager' : 'a staff member'
}

export function roleLabel(role: string, isPrimaryOwner = false): string {
  if (isPrimaryOwner) return 'Owner'
  return role === 'Manager' ? 'Manager' : 'Staff'
}

/**
 * DateTimes read back from SQL Server have Kind=Unspecified, so the API serializes them without a "Z"
 * and the browser would treat them as local time. Everything here is UTC.
 */
export function parseUtc(iso: string): Date {
  return new Date(/Z|[+-]\d{2}:?\d{2}$/.test(iso) ? iso : `${iso}Z`)
}

export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(parseUtc(iso))
}