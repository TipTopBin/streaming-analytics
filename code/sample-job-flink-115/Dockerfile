# FROM maven:3.8.6-jdk-8-slim AS builder # 免费账户有速率限制
FROM public.ecr.aws/docker/library/maven:3.8.6-amazoncorretto-11 AS builder 
COPY src/ /home/app/src
COPY pom.xml /home/app/
RUN ls -l /home/app
RUN mvn -f /home/app/pom.xml clean package -Dflink.version=1.15.1

# FROM flink:1.15.1
FROM public.ecr.aws/docker/library/flink:1.15.1-java11
RUN mkdir -p $FLINK_HOME/usrlib
COPY --from=builder /home/app/target/aws-kinesis-analytics-java-apps-1.0.jar $FLINK_HOME/usrlib/aws-kinesis-analytics-java-apps-1.0.jar
RUN mkdir $FLINK_HOME/plugins/s3-fs-hadoop
COPY /lib/flink-s3-fs-hadoop-1.15.1.jar $FLINK_HOME/plugins/s3-fs-hadoop/