<?php

command("/home/naoko/alterlinux-pkgbuilds/get_from_aur.sh");
command("/home/naoko/alterlinux-repository/scripts/main.sh");

function command($cmd){
    exec($cmd, $opt, $return);
    $opt_str="";
    foreach ($opt as $value) {
        $opt_str.=$value."\n";
    }
    if ($return===1) {
        $data=[
            "status" => "ERROR",
            "output" => $cmd."\n".$opt_str
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
            "output" => $cmd."\n".$opt_str
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
}