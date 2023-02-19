variable "eks_cluster_id" {
  description = "EKS Cluster ID"
  type        = string
  default     = module.cluster.eks_cluster_id 
}