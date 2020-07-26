<?php 

$json = file_get_contents("php://input");
$contents = json_decode($json, true);
exec("php exec.php ".  $contents["callbackurl"]." ".
                        $contents["architecture"]." ".
                        $contents["repository"]." ".
                        $contents["package"]." ".
                        $contents["what"]." > /dev/null &", $opt, $return);

$opt_str="";
foreach ($opt as $value) {
    $opt_str.=$value."\n";
}

if ($return===1) {
    $data=[
        "status" => "ERROR",
        "output" => "リポジトリの更新作業の開始に失敗しました\n".$opt_str
    ];
    $data = json_encode($data);
    echo $data;
}elseif ($return===0) {
    $data=[
        "status" => "OK",
        "output" => "リポジトリの更新作業の開始に成功しました\n".$opt_str
    ];
    $data = json_encode($data);
    echo $data;
}