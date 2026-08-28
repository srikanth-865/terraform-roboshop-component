variable "project"{
    default = "Roboshop1"
}
variable "environment"{
    default = "Dev"
}
variable "components"{
   type = string # we just intialize in this module declare by source module
}

variable "app_version"{
    default = "v3"
}