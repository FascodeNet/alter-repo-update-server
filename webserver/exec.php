<?php

$cmd = 'ls -l /usr';
exec($cmd, $opt, $return);
$opt_str="";
foreach ($opt as $value) {
    $opt_str.=$value."\n";
}
if ($return===1) {
    $data=[
        "status" => "ERROR",
        "output" => $opt_str
    ];
    $data = json_encode($data);
    $context = stream_context_create(
        array(
            'http' => array(
                'method'=> 'POST',
                'header'=> 'Content-type: application/json; charset=UTF-8',
                'content' => $data
            )
        )
    );

    $responses_json = file_get_contents($argv[1], false, $context);
}elseif ($return===0) {
    $data=[
        "status" => "OK",
        "output" => $opt_str
    ];
    $data = json_encode($data);
    $context = stream_context_create(
        array(
            'http' => array(
                'method'=> 'POST',
                'header'=> 'Content-type: application/json; charset=UTF-8',
                'content' => $data
            )
        )
    );

    $responses_json = file_get_contents($argv[1], false, $context);
}
