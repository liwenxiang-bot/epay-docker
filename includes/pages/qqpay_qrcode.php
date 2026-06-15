<?php
// QQ钱包扫码支付页面

if(!defined('IN_PLUGIN'))exit();
?>
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="Content-Language" content="zh-cn">
<meta name="renderer" content="webkit">
<title>QQ钱包扫码支付</title>
<link href="/assets/css/mqq_pay.css?v=1" rel="stylesheet" media="screen">
</head>
<body>
<div class="body">
<h1 class="mod-title">
<span class="ico-wechat"></span><span class="text">QQ钱包扫码支付</span>
</h1>
<div class="mod-ct">
<div class="order">
</div>
<div class="amount">￥<?php echo $order['realmoney']?></div>
<div class="qr-image" id="qrcode">
</div>
 
<div class="detail" id="orderDetail">
<dl class="detail-ct" style="display: none;">
<dt>商家</dt>
<dd id="storeName"><?php echo $sitename?></dd>
<dt>购买物品</dt>
<dd id="productName"><?php echo $order['name']?></dd>
<dt>商户订单号</dt>
<dd id="billId"><?php echo $order['trade_no']?></dd>
<dt>创建时间</dt>
<dd id="createTime"><?php echo $order['addtime']?></dd>
</dl>
<a href="javascript:void(0)" class="arrow"><i class="ico-arrow"></i></a>
</div>
<div class="tip">
<span class="dec dec-left"></span>
<span class="dec dec-right"></span>
<div class="ico-scan"></div>
<div class="tip-text">
<p>请使用手机QQ扫一扫</p>
<p>扫描二维码完成支付</p>
</div>
</div>
<div class="tip-text">
</div>
</div>
<div class="foot">
<div class="inner">
<p>手机用户可保存上方二维码到手机中</p>
<p>在手机QQ扫一扫中选择“相册”即可</p>
</div>
</div>
</div>
<script src="/assets/js/jquery-1.12.4.min.js"></script>
<script src="<?php echo $cdnpublic?>layer/3.1.1/layer.min.js"></script>
<script src="/assets/js/jquery.qrcode.min.js"></script>
<script>
    var code_url = '<?php echo $code_url?>';
    var code_type = code_url.indexOf('data:image/')>-1?1:0;
    $(function(){
        if(code_type == 0){
            try {
                $('#qrcode').qrcode({
                    text: code_url,
                    width: 230,
                    height: 230,
                    foreground: "#000000",
                    background: "#ffffff",
                    typeNumber: -1
                });
            } catch(e) {
                $('#qrcode').html('<div style="padding:20px;color:#f00;">二维码加载失败<br/><a href="javascript:location.reload()" style="display:inline-block;margin-top:10px;padding:6px 20px;background:#1677ff;color:#fff;border-radius:4px;text-decoration:none;">点击重试</a></div>');
            }
        }else{
            $('#qrcode').html('<img src="'+code_url+'"/>');
        }
    });
    // 订单详情
    $('#orderDetail .arrow').click(function (event) {
        if ($('#orderDetail').hasClass('detail-open')) {
            $('#orderDetail .detail-ct').slideUp(500, function () {
                $('#orderDetail').removeClass('detail-open');
            });
        } else {
            $('#orderDetail .detail-ct').slideDown(500, function () {
                $('#orderDetail').addClass('detail-open');
            });
        }
    });
    function loadmsg() {
        $.ajax({
            type: "GET",
            dataType: "json",
            url: "/getshop.php",
            data: {type: "qqpay", trade_no: "<?php echo $order['trade_no']?>"},
            success: function (data) {
                if (data.code == 1) {
					layer.msg('支付成功，正在跳转中...', {icon: 16,shade: 0.1,time: 15000});
					setTimeout(function(){window.location.href=data.backurl;}, 1000);
                }else{
                    setTimeout(loadmsg, 2000);
                }
            },
            error: function () {
                setTimeout(loadmsg, 2000);
            }
        });
    }
    window.onload = function(){
        setTimeout(loadmsg, 2000);
    }
</script>
</body>
</html>