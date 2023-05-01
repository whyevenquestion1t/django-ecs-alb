resource "aws_ecs_cluster" "production" {
  name = "${var.ecs_cluster_name}-cluster"
}

resource "aws_launch_template" "ecs" {
  name          = "${var.ecs_cluster_name}-cluster"
  image_id      = lookup(var.amis, var.region)
  instance_type = var.instance_type
  network_interfaces {
    associate_public_ip_address = true
  }
  #   security_groups             = [aws_security_group.ecs.id]
  #   iam_instance_profile        = aws_iam_instance_profile.ecs.name
  key_name   = aws_key_pair.production.key_name
  user_data  = "IyEvYmluL2Jhc2hcbmVjaG8gRUNTX0NMVVNURVI9J3Byb2R1Y3Rpb24tY2x1c3RlcicgPj4gL2V0Yy9lY3MvZWNzLmNvbmZpZw=="
  depends_on = [aws_ecs_cluster.production]
}





# data "template_file" "app" {
#   template = file("templates/django_app.json.tpl")

#   vars = {
#     docker_image_url_django = var.docker_image_url_django
#     region                  = var.region
#   }
# }

resource "aws_ecs_task_definition" "app" {
  family = "django-app"
  container_definitions = jsonencode([
    {
      "name" : "django-app",
      "image" : "193190103167.dkr.ecr.us-east-1.amazonaws.com/django-app",
      "essential" : true,
      "cpu" : 10,
      "memory" : 256,
      "links" : [],
      "portMappings" : [
        {
          "containerPort" : 8000,
          "hostPort" : 0,
          "protocol" : "tcp"
        }
      ],
      "command" : ["gunicorn", "-w", "3", "-b", ":8000", "hello_django.wsgi:application"],
      "environment" : [],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "/ecs/django-app",
          "awslogs-region" : "us-east-1",
          "awslogs-stream-prefix" : "django-app-log-stream"
        }
      }
    }
  ])
  # container_definitions = data.template_file.app.rendered
}

resource "aws_ecs_service" "production" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.production.id
  task_definition = aws_ecs_task_definition.app.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "django-app"
    container_port   = 8000
  }
}