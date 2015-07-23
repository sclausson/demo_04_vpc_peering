#!/usr/bin/env ruby
require 'trollop'
require 'aws-cfn-resources'

@opts = Trollop::options do
  opt :stackname, "Name of this CFN stack that you are creating", :type => String, :required => true, :short => "s"
  opt :vpc_stackname, "Name of the stack used when creating the VPC", :type => String, :required => true, :short => "v"
  opt :template, "Name of the CFN template file", :type => String, :required => true, :short => "t"
  opt :region, "AWS region where the stack will be created", :type => String, :required => true, :short => "r"
  opt :default_vpc_cidr, "CIDR block of the default VPC", :type => String, :default => "172.30.0.0/16"
  opt :default_vpc_id, "VPC ID of the Default VPC", :type => String, :required => true
  opt :default_route_table_id, "Main route table ID in the default VPC", :type => String, :required => true
end

AWS.config(region: @opts[:region])

cfn = AWS::CloudFormation.new
@vpc_stack = cfn.stacks[@opts[:vpc_stackname]]

def parameters
  parameters = {
    "defaultVpcCidr"            => @opts[:default_vpc_cidr],
    "defaultVpcId"              => @opts[:default_vpc_id],
    "defaultVpcRouteTableId"    => @opts[:default_route_table_id],
    "newVpcCidr"                => @vpc_stack.vpc('VPC').cidr_block,
    "newVpcId"                  => @vpc_stack.vpc('VPC').id,
    "newVpcRouteTableId"        => @vpc_stack.route_table('PublicRouteTable').id,
    "newVpcDefaultSgId"         => @vpc_stack.vpc('VPC').security_groups.find { |sg| sg.name == 'default' }.id
  }
  return parameters
end

def template
  file = "./templates/#{@opts[:template]}"
  body = File.open(file, "r").read
  return body
end

cfn.stacks.create(@opts[:stackname], template, parameters: parameters, capabilities: ["CAPABILITY_IAM"])

print "Waiting for stack #{@opts[:stackname]} to complete"

until cfn.stacks[@opts[:stackname]].status == "CREATE_COMPLETE"
  print "."
  sleep 5
end


