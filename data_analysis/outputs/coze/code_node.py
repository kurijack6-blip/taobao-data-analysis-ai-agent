import json

async def main(args):
    data = json.loads(args.params['input_json'])
    
    uv_total = float(data.get('uv_total', 0))
    uv_cart = float(data.get('uv_cart', 0))
    uv_fav = float(data.get('uv_fav', 0))
    uv_buy = float(data.get('uv_buy', 0))
    cart_rate = float(data.get('cart_to_buy_rate', 0))
    fav_rate = float(data.get('fav_to_buy_rate', 0))
    
    # 计算各项指标
    access_to_cart = round(uv_cart / uv_total * 100, 2) if uv_total > 0 else 0
    access_to_fav = round(uv_fav / uv_total * 100, 2) if uv_total > 0 else 0
    access_to_buy = round(uv_buy / uv_total * 100, 2) if uv_total > 0 else 0
    fav_penetration = round(uv_fav / uv_total * 100, 2) if uv_total > 0 else 0
    rate_gap = round(abs(cart_rate - fav_rate) * 100, 2)
    
    result = {
        "access_to_cart_rate": f"{access_to_cart}%",
        "access_to_fav_rate": f"{access_to_fav}%",
        "access_to_buy_rate": f"{access_to_buy}%",
        "fav_penetration": f"{fav_penetration}%",
        "cart_fav_rate_gap": f"{rate_gap}个百分点",
        "is_signal_homogeneous": rate_gap < 3
    }
    return result