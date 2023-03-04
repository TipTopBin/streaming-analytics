FROM public.ecr.aws/docker/library/maven:3.8.6-amazoncorretto-8 AS builder 
COPY src/ /home/app/src
COPY pom.xml /home/app/pom.xml
RUN ls -l /home/app
RUN mvn -f /home/app/pom.xml clean package -Dflink.version=1.13.2

# FROM flink:1.13.2
FROM public.ecr.aws/w3z8i2u5/flink-base:1.13-scala_2.11-java8
RUN mkdir -p $FLINK_HOME/usrlib
COPY --from=builder /home/app/target/aws-kinesis-analytics-java-apps-1.0.jar $FLINK_HOME/usrlib/aws-kinesis-analytics-java-apps-1.0.jar
RUN mkdir $FLINK_HOME/plugins/s3-fs-hadoop
COPY /lib/flink-s3-fs-hadoop-1.13.0.jar $FLINK_HOME/plugins/s3-fs-hadoop/