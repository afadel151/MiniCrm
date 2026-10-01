
export type MemberRole = 'Manager' | 'Staff'
export type InvitationStatus = 'Pending' | 'Accepted' | 'Revoked' | 'Expired'
export type InviteeAccountState = 'NoAccount' | 'BusinessAccount' | 'ClientAccount' | 'OtherAccount'

export interface InvitationPreview {
  businessName: string
  inviterName: string
  role: MemberRole
  emailHint: string
  status: InvitationStatus
  accountState: InviteeAccountState
  expiresAtUtc: string
}

export interface AcceptInvitationResult {
  businessId: number
  businessName: string
  role: MemberRole
  alreadyMember: boolean
}

export interface JoinResult {
  signedIn: boolean
  businessId: number
  businessName: string
  role: MemberRole
}

export interface CreatedInvitation {
  id: number
  email: string
  role: MemberRole
  expiresAtUtc: string
  emailSent: boolean
}

export interface InvitationListItem {
  id: number
  email: string
  role: MemberRole
  status: InvitationStatus
  createdAtUtc: string
  expiresAtUtc: string
  invitedByName: string
}

export interface BusinessDetailDto {
  id: number
  businessName: string
  description: string | null
  website: string | null
  businessAdress: string | null
  isActive: boolean
  membershipCount: number
  myRole: MemberRole
  iAmPrimaryOwner: boolean
  rowVersion: string
}

export interface MemberDto {
  membershipId: number
  userId: string
  fullName: string
  email: string
  role: MemberRole
  isPrimaryOwner: boolean
  isActive: boolean
  createdAtUtc: string
}