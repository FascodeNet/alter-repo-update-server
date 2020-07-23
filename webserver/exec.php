<?php

ini_set("register_argc_argv",1);
command("/home/naoko/alterlinux-pkgbuilds/get_from_aur.sh",$argv[1]);
command("/home/naoko/alterlinux-repository/scripts/main.sh",$argv[1]);

function command($cmd,$arg){
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

        $responses_json = file_get_contents($arg, false, $context);
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

        $responses_json = file_get_contents($arg, false, $context);
        error_log($responses_json);
    }
}
