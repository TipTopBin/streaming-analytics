locals {

    emr_eks_spark = {
      namespace               = "emr-spark"
      job_execution_role      = "emr-eks-spark"
      additional_iam_policies = []
    }
    
    emr_eks_flink = {
      namespace               = "emr-flink"
      job_execution_role      = "emr-eks-flink"
      additional_iam_policies = []
    }
    
    emr_service_name = "emr-containers"

}