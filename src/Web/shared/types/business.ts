export interface BusinessInfosResult {
  infos: BusinessInfo[];
}

export interface BusinessInfo {
  id: number;
  businessName: string;
  isActive: boolean;
  membershipCount: number;
  membershipInfo: MembershipInfo;
}

export interface MembershipInfo {
  id: number;
  role: BusinessMemberRole;
  isActive: boolean;
}

export interface CreateBusinessDto {
  businessName: string;
  description: string;
  businessDomain: BusinessDomain;
  businessAdress?: string;
  website?: string;
}

export enum BusinessMemberRole {
  BusinessManager = "BusinessManager",
  BusinessStaff = "BusinessStaff",
}

export enum BusinessDomain {
  Technology = "Technology",
  Finance = "Finance",
  Healthcare = "Healthcare",
  Education = "Education",
  ProfessionalServices = "ProfessionalServices",
  SalesAndMarketing = "SalesAndMarketing",
  RetailAndCommerce = "RetailAndCommerce",
  Manufacturing = "Manufacturing",
  ConstructionAndRealEstate = "ConstructionAndRealEstate",
  EngineeringAndArchitecture = "EngineeringAndArchitecture",
  TransportationAndLogistics = "TransportationAndLogistics",
  Automotive = "Automotive",
  AgricultureAndFood = "AgricultureAndFood",
  HospitalityAndTourism = "HospitalityAndTourism",
  MediaAndEntertainment = "MediaAndEntertainment",
  Telecommunications = "Telecommunications",
  EnergyAndUtilities = "EnergyAndUtilities",
  GovernmentAndPublicSector = "GovernmentAndPublicSector",
  NonProfit = "NonProfit",
  SecurityAndDefense = "SecurityAndDefense",
  Other = "Other"
}