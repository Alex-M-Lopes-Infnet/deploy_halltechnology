echo '####################### CRIANDO AMBIENTE DE REDE ####################################'
echo
echo '### CRIANDO VPC ###'
#Criando a VPC
vpc=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPC_ecommerce}]' --query Vpc.VpcId --output text)
echo VPC Criada - 10.10.0.0/16

#Criando internet gateway
internet_gateway=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
echo Internet Gateway Criado

#Anexando o Internet Gateway a VPC
aws ec2 attach-internet-gateway --vpc-id $vpc --internet-gateway-id $internet_gateway
echo Internet Gateway anexado a VPC
echo ''
echo '### CRIANDO SUBNETS ###'
echo ''
#Criando SubNet 10.10.1.0/24 - Zona de disponibilidade us-east-1a
subnet_publica_a=$(aws ec2 create-subnet --vpc-id $vpc --cidr-block 10.10.1.0/24 --availability-zone us-east-1a --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $subnet_publica_a --tags Key=Name,Value=subnet_publica_a
echo Criada subnet_publica_a - 10.10.1.0/24

#Criando SubNet 10.10.2.0/24 - Zona de disponibilidade us-east-1b
subnet_publica_b=$(aws ec2 create-subnet --vpc-id $vpc --cidr-block 10.10.2.0/24 --availability-zone us-east-1b --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $subnet_publica_b --tags Key=Name,Value=subnet_publica_b
echo Criada subnet_publica_b - 10.10.2.0/24

#Criando SubNet 10.10.3.0/24 - Zona de disponibilidade us-east-1a
subnet_privada_a=$(aws ec2 create-subnet --vpc-id $vpc --cidr-block 10.10.3.0/24 --availability-zone us-east-1a --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $subnet_privada_a --tags Key=Name,Value=subnet_privada_a
echo Criada subnet_privada_a - 10.10.3.0/24

#Criando SubNet 10.10.4.0/24 - Zona de disponibilidade us-east-1b
subnet_privada_b=$(aws ec2 create-subnet --vpc-id $vpc --cidr-block 10.10.4.0/24 --availability-zone us-east-1b --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $subnet_privada_b --tags Key=Name,Value=subnet_privada_b
echo Criada subnet_privada_b - 10.10.4.0/24

#Criando os NatGateway para permitir comunicação das instancias na rede privada com a internet
echo ''
echo '### CRIANDO NATGATEWAYs ###'
echo ''
#Alocando IP Público para Nat GateWay A
eip_01=$(aws ec2 allocate-address | grep AllocationId | cut -f 4 -d '"')
#aws ec2 create-tags --resources $eip_01--tags Key=Name,Value=IP_nat_gateway_a
echo Alocado endereço IPV4 público

#Criando NAT GateWay para subnet_publica_a 
nat_gateway_a=$(aws ec2 create-nat-gateway --subnet-id $subnet_publica_a --allocation-id $eip_01 | grep NatGatewayId | cut -f 4 -d '"')
aws ec2 create-tags --resources $nat_gateway_a --tags Key=Name,Value=NT_SN_publica_a
echo Criado NatGateway na subnet_publica_a

#Alocando IP Público para Nat GateWay B
eip_02=$(aws ec2 allocate-address | grep AllocationId | cut -f 4 -d '"')
#aws ec2 create-tags --resources $eip_02--tags Key=Name,Value=IP_nat_gateway_b
echo Alocado endereço IPV4 público

#Criando NAT GateWay para subnet_publica_b 
nat_gateway_b=$(aws ec2 create-nat-gateway --subnet-id $subnet_publica_b --allocation-id $eip_02 | grep NatGatewayId | cut -f 4 -d '"')
aws ec2 create-tags --resources $nat_gateway_b --tags Key=Name,Value=NT_SN_publica_b
echo Criado NatGateway na subnet_publica_b

##Criando tabelas de Rotas

echo ''
echo '### CRIANDO TABELAS DE ROTAS ###'
echo ''

#Criando Tabela de Rotas Publica
route_table_publica=$(aws ec2 create-route-table --vpc-id $vpc --query RouteTable.RouteTableId --output text)
aws ec2 create-tags --resources $route_table_publica --tags Key=Name,Value=route_table_publica
echo Criada Tabela de roteamento para subnets públicas

#Criando o roteamento subnet pública
null=$(aws ec2 create-route --route-table-id $route_table_publica --destination-cidr-block 0.0.0.0/0 --gateway-id $internet_gateway)
echo Criado rota na tabela de roteamento pública direcionando o tráfego para o Internet Gateway 

#Criando Tabela de Rotas para subnet subnet_privada_a
route_table_subnet_privada_a=$(aws ec2 create-route-table --vpc-id $vpc --query RouteTable.RouteTableId --output text)
aws ec2 create-tags --resources $route_table_subnet_privada_a --tags Key=Name,Value=RT_subnet_privada_a
echo Criada Tabela de roteamento para subnet_privada_a

#Criando o roteamento na route_table_subnet_privada_a
null=$(aws ec2 create-route --route-table-id $route_table_subnet_privada_a --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_gateway_a)
echo Criado rota na tabela de roteamento RT_subnet_privada_a direcionando o tráfego da subnet_privada_a para o nat_gateway_a

#Criando Tabela de Rotas para subnet subnet_privada_b
route_table_subnet_privada_b=$(aws ec2 create-route-table --vpc-id $vpc --query RouteTable.RouteTableId --output text)
aws ec2 create-tags --resources $route_table_subnet_privada_b --tags Key=Name,Value=RT_subnet_privada_b
echo Criada Tabela de roteamento para subnet_privada_b

#Criando o roteamento na route_table_subnet_privada_b
null=$(aws ec2 create-route --route-table-id $route_table_subnet_privada_b --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_gateway_b)
echo Criado rota na tabela de roteamento RT_subnet_privada_b direcionando o tráfego da subnet_privada_b para o nat_gateway_b

#Associando a tabela de roteamento na SubNet subnet_publica_a
null=$(aws ec2 associate-route-table --subnet-id $subnet_publica_a --route-table-id $route_table_publica)
echo Associando tabela de roteamento pública a subnet_publica_a

#Associando a tabela de roteamento na SubNet subnet_publica_b
null=$(aws ec2 associate-route-table --subnet-id $subnet_publica_b --route-table-id $route_table_publica)
echo Associando tabela de roteamento pública a subnet_publica_b

#Associando a tabela de roteamento na SubNet subnet_privada_a
null=$(aws ec2 associate-route-table --subnet-id $subnet_privada_a --route-table-id $route_table_subnet_privada_a)
echo Anexando route table RT_subnet_privada_a na subnet_privada_a

#Associando a tabela de roteamento na SubNet subnet_privada_b
null=$(aws ec2 associate-route-table --subnet-id $subnet_privada_b --route-table-id $route_table_subnet_privada_b)
echo Anexando route table RT_subnet_privada_b na subnet_privada_b

###################################### PROVISÓRIO ########################################
#roteamento provisório enquanto não é fechado uma VPN com a AWS
#Será criado uma rota permitindo comunicação entra as subredes privadas e o ip(dinâmico) da rede local
#Este trecho deverá ser removido após estabelecida comunicação entre a rede local e a VPC
meu_IP=$(wget -qO- http://ipecho.net/plain | cut -f 1 -d '%')
minha_rede=$(echo $meu_IP/32)
null=$(aws ec2 create-route --route-table-id $route_table_subnet_privada_a --destination-cidr-block $minha_rede --gateway-id $internet_gateway)
null=$(aws ec2 create-route --route-table-id $route_table_subnet_privada_b --destination-cidr-block $minha_rede --gateway-id $internet_gateway)
###################################### FIM DO TRECHO PROVISÓRIO ########################################

echo '####################### AMBIENTE DE REDE FINALIZADO ####################################'
echo
echo '########################### CRIANDO SECURITY GROUPS ####################################'
echo
#Criando Security Group para o Load Balancer
load_balancer_sg=$(aws ec2 create-security-group --group-name "SG_Load_Balancer" --description "Security Group para mermitir trafego da internet para o Load Balancer" --vpc-id $vpc --query GroupId --output text)
aws ec2 create-tags --resources $load_balancer_sg --tags Key=Name,Value=SG_Load_Balancer
echo Criado Security Group para o Load Balancer

#Liberando porta 80
null=$(aws ec2 authorize-security-group-ingress --group-id $load_balancer_sg --protocol tcp --port 80 --cidr 0.0.0.0/0)
echo Liberada a porta 80 vinda da internet

#Criando Security Group para os servidores de aplicação
app_srv_sg=$(aws ec2 create-security-group --group-name "SG_Aplicacao" --description "Security Group para mermitir trafego da internet para porta 22" --vpc-id $vpc --query GroupId --output text)
aws ec2 create-tags --resources $app_srv_sg --tags Key=Name,Value=SG_Aplicacao
echo Criado Security Group para os servidores de aplicação

#Liberando porta 22
null=$(aws ec2 authorize-security-group-ingress --group-id $app_srv_sg --protocol tcp --port 22 --cidr 0.0.0.0/0)
echo Liberada a porta 22 vinda da internet

#Liberando porta 80
null=$(aws ec2 authorize-security-group-ingress --group-id $app_srv_sg --protocol tcp --port 80 --source-group $load_balancer_sg) #--cidr 0.0.0.0/0
echo Liberada a porta 80 vinda de load_balancer_sg

echo ''
echo '#################################### CRIANDO INSTÂNCIAS ####################################'

#Criando Instância App01
app01=$(aws ec2 run-instances --image-id ami-04902260ca3d33422 --count 1 --instance-type t2.micro --key-name key_projeto --security-group-ids $app_srv_sg --subnet-id $subnet_privada_a --associate-public-ip-address | grep InstanceId | cut -f 4 -d '"')
aws ec2 create-tags --resources $app01 --tags Key=Name,Value=App01
aws ec2 describe-instances --filters "Name=tag:Name,Values=App01" | grep PublicIpAddress | cut -f 4 -d '"' >> /home/alex/Projetos/deploy_halltechnology/hosts
echo Instância App01 Criada

#Criando Instância App02
app02=$(aws ec2 run-instances --image-id ami-04902260ca3d33422 --count 1 --instance-type t2.micro --key-name key_projeto --security-group-ids $app_srv_sg --subnet-id $subnet_privada_b --associate-public-ip-address | grep InstanceId | cut -f 4 -d '"')
aws ec2 create-tags --resources $app02 --tags Key=Name,Value=App02
aws ec2 describe-instances --filters "Name=tag:Name,Values=App02" | grep PublicIpAddress | cut -f 4 -d '"' >> /home/alex/Projetos/deploy_halltechnology/hosts
echo Instância App02 Criada

sleep 25s # Waits 25 seconds.

echo '#################################### INSTÂNCIAS FINALIZADAS ####################################'
echo ''
echo '########################### CRIANDO APLICATION LOAD BALANCER ####################################'

#Criando Load Balancer
null=$(aws elbv2 create-load-balancer --name ecommerce --subnets $subnet_publica_a $subnet_publica_b --type application --security-group $load_balancer_sg)
sleep 10s # Waits 10 seconds.
load_balance=$(aws elbv2 describe-load-balancers | grep LoadBalancerArn | cut -f 4 -d '"')
echo Load Balancer Criado

#Criando Target group
target_group=$(aws elbv2 create-target-group --name ecommerce-target --protocol HTTP --port 80 --vpc-id $vpc | grep TargetGroupArn | cut -f 4 -d '"')
echo Target group Criado

#Adicionando instâncias ao target do load balance
null=$(aws elbv2 register-targets --target-group-arn $target_group --targets Id=$app01 Id=$app02)
echo Instâncias adicionadas ao target load balancer

#Criando Listener
listener=$(aws elbv2 create-listener --load-balancer-arn $load_balance --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$target_group | grep ListenerArn | cut -f 4 -d '"')
echo Listener Criado

echo '########################### APLICATION LOAD BALANCER FINALIZADO ####################################'
echo ''
