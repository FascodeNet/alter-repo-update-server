<?php

ini_set("register_argc_argv",1);
command("/srv/php/alterlinux-pkgbuilds/get_from_aur.sh -a ".$argv[2]." -r ".$argv[3]." ".$argv[4],$argv[1]);
command("/srv/php/alterlinux-repository/main.sh --force-repo -a ".$argv[2]." -r ./repo -f ".$argv[3]." ".$argv[5],$argv[1]);

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