package com.amazonaws.services.kinesisanalytics;

import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kinesis.FlinkKinesisConsumer;
import org.apache.flink.streaming.connectors.kinesis.config.ConsumerConfigConstants;
import org.apache.flink.api.common.serialization.SimpleStringEncoder;
import org.apache.flink.runtime.state.hashmap.HashMapStateBackend;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.JsonNode;
import org.apache.flink.shaded.jackson2.com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.util.Collector;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.functions.sink.filesystem.bucketassigners.DateTimeBucketAssigner;
import org.apache.flink.contrib.streaming.state.EmbeddedRocksDBStateBackend;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class S3StreamingSinkJob {
    private static String region = null;
    private static String inputStreamName = null;
    private static String s3SinkPath = null;
    private static String checkpointType = "s3";
    private static String checkpointDir = null;
    private static int checkpointInterval = 10000;
    private static int windowStart = 10;
    private static int windowEnd = 5;
    private static int operatorParallelism = 8; // default

    private static final Logger log = LoggerFactory.getLogger(S3StreamingSinkJob.class);
    
    private static DataStream<String> createSourceFromStaticConfig(StreamExecutionEnvironment env) {

        Properties inputProperties = new Properties();
        inputProperties.setProperty(ConsumerConfigConstants.AWS_REGION, region);
        inputProperties.setProperty(ConsumerConfigConstants.STREAM_INITIAL_POSITION,
                "LATEST");
        return env.addSource(new FlinkKinesisConsumer<>(inputStreamName,
                new SimpleStringSchema(),
                inputProperties));
    }

    private static StreamingFileSink<String> createS3SinkFromStaticConfig() {

        final StreamingFileSink<String> sink = StreamingFileSink
                .forRowFormat(new Path(s3SinkPath), new SimpleStringEncoder<String>("UTF-8"))
                .withBucketAssigner(new DateTimeBucketAssigner("yyyy-MM-dd--HH"))
                .build();
        return sink;
    }
     
    public static void main(String[] args) throws Exception {
        
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        final ParameterTool params = ParameterTool.fromArgs(args);
        env.disableOperatorChaining(); // For debug

        checkpointDir = params.get("checkpoint-dir");
        region = params.get("region");
        s3SinkPath = params.get("s3SinkPath"); 
        inputStreamName = params.get("inputStreamName"); 

        if (params.get("windowStart") != null) {
            windowStart = Integer.parseInt(params.get("windowStart"));
        }

        if (params.get("windowEnd") != null) {
            windowEnd = Integer.parseInt(params.get("windowEnd"));
        }

        if (params.get("checkpointType") != null) {
            checkpointType = params.get("checkpointType");
        }

        if (params.get("checkpointInterval") != null) {
            checkpointInterval = Integer.parseInt(params.get("checkpointInterval"));
        }

        if (params.get("operatorParallelism") != null) {
            operatorParallelism = Integer.parseInt(params.get("operatorParallelism"));
        }

		log.info("---Input Params---");
		log.info("inputStreamName: {}, s3SinkPath: {}, region: {}, checkpointInterval: {}, checkpointDir: {}, windowStart: {}, windowEnd: {}, operatorParallelism: {}",
         inputStreamName, s3SinkPath, region, checkpointInterval, checkpointDir, windowStart, windowEnd, operatorParallelism);

        log.info("--- Env Debug---");
        log.info("ENV toString: {}", env.toString());
        log.info("Parallelism: {}", env.getParallelism());
        log.info("MaxParallelism: {}", env.getMaxParallelism());

        // state 
        // https://nightlies.apache.org/flink/flink-docs-stable/docs/ops/state/state_backends/#migrating-from-legacy-backends            
        env.setStateBackend(new HashMapStateBackend());

        // checkpoint https://nightlies.apache.org/flink/flink-docs-master/docs/dev/datastream/fault-tolerance/checkpointing/
        env.enableCheckpointing(checkpointInterval); // Every 10 sec 从命令行传入        
        env.getCheckpointConfig().setCheckpointStorage(checkpointDir);
        // env.setStateBackend(new EmbeddedRocksDBStateBackend());
        // env.getCheckpointConfig().setCheckpointStorage("file:///tmp");        

        env.setStreamTimeCharacteristic(TimeCharacteristic.IngestionTime);
        
        DataStream<String> input = createSourceFromStaticConfig(env);

        ObjectMapper jsonParser = new ObjectMapper();


        // DataStream<String> SourceFromKinesis = createSourceFromStaticConfig(env);
        // SourceFromKinesis.addSink(createS3SinkFromStaticConfig());

        input.map(value -> {
            JsonNode jsonNode = jsonParser.readValue(value, JsonNode.class);
            return new Tuple2<>(jsonNode.get("TICKER").asText(), jsonNode.get("PRICE").asDouble());
        }).returns(Types.TUPLE(Types.STRING, Types.DOUBLE))
                .keyBy(0) // Logically partition the stream per stock symbol
                // .timeWindow(Time.seconds(10), Time.seconds(5))  // Sliding window definition https://nightlies.apache.org/flink/flink-docs-master/api/java/org/apache/flink/streaming/api/windowing/windows/TimeWindow.html
                .timeWindow(Time.seconds(windowStart), Time.seconds(windowEnd))  // Sliding window definition https://nightlies.apache.org/flink/flink-docs-master/api/java/org/apache/flink/streaming/api/windowing/windows/TimeWindow.html
                .max(1) // Calculate mamximum price per stock over the window
                .setParallelism(operatorParallelism) // Set parallelism for the min operator
                .map(value -> value.f0 + "," + value.f1 + "," + value.f1.toString() + "\n")
                .addSink(createS3SinkFromStaticConfig()).name("S3_sink");

        // input.flatMap(new Tokenizer()) // Tokenizer for generating words
        //         .keyBy(0) // Logically partition the stream for each word
        //         .timeWindow(Time.minutes(1)) // Tumbling window definition
        //         .sum(1) // Sum the number of words per partition
        //         .map(value -> value.f0 + " count: " + value.f1.toString() + "\n")
        //         .addSink(createS3SinkFromStaticConfig());

        env.execute("Flink S3 Streaming Sink Job");
    }
    

}