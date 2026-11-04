# -*- coding: utf-8 -*-
"""星辰影音 - 演示 Python 源（TVBox / 催壳风格接口）"""

def homeContent(filter=False):
    return {
        "class": [
            {"type_id": "1", "type_name": "电影"},
            {"type_id": "2", "type_name": "剧集"},
            {"type_id": "3", "type_name": "综艺"},
            {"type_id": "4", "type_name": "动漫"},
        ],
        "list": homeVideoContent(),
    }


def homeVideoContent():
    names = [
        "星际穿越", "盗梦空间", "寄生虫", "千与千寻",
        "你的名字", "流浪地球", "哪吒之魔童降世", "肖申克的救赎",
    ]
    arr = []
    for i, n in enumerate(names):
        arr.append({
            "vod_id": "py_%d" % i,
            "vod_name": n,
            "vod_pic": "https://picsum.photos/seed/py%d/300/450" % i,
            "vod_remarks": "高清" if i % 2 == 0 else "更新至%d集" % (i + 8),
            "vod_year": "202%d" % (i % 5),
            "type_name": "电影" if i % 2 == 0 else "剧集",
        })
    return arr


def categoryContent(tid, pg, filter, extend):
    pg = int(pg or 1)
    if pg > 3:
        return {"list": []}
    items = homeVideoContent()
    for i, v in enumerate(items):
        v["vod_id"] = "py_cat_%s_%s_%d" % (tid, pg, i)
        v["vod_name"] = "%s · P%s" % (v["vod_name"], pg)
        v["type_name"] = "电影" if str(tid) == "1" else "剧集"
    return {"list": items}


def detailContent(ids):
    vid = ids[0] if isinstance(ids, list) else ids
    return {
        "list": [{
            "vod_id": vid,
            "vod_name": "Python演示影片",
            "vod_pic": "https://picsum.photos/seed/pydetail/300/450",
            "vod_year": "2024",
            "vod_area": "中国大陆",
            "type_name": "剧情",
            "vod_actor": "演员A / 演员B",
            "vod_director": "导演C",
            "vod_content": "由 Python 运行时返回的详情（对标催壳/TVBox spider）。",
            "vod_play_from": "线路1$$$线路2",
            "vod_play_url":
                "第01集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
                "#第02集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
                "$$$第01集$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        }]
    }


def searchContent(key, quick, pg=1):
    pg = int(pg or 1)
    if pg > 2:
        return {"list": []}
    items = homeVideoContent()[:6]
    for i, v in enumerate(items):
        v["vod_id"] = "py_s_%s_%d" % (pg, i)
        v["vod_name"] = "%s · %s" % (key, v["vod_name"])
    return {"list": items}


def playerContent(flag, id, vipFlags=None):
    return {
        "parse": 0,
        "url": id,
        "header": {},
        "danmaku": "asset://assets/media/demo_danmaku.json",
        "subtitles": [
            {"name": "中文外挂", "url": "asset://assets/media/demo.srt", "lang": "zh"}
        ],
    }
