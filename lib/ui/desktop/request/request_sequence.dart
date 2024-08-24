import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/desktop/request/model/search_model.dart';
import 'package:network_proxy/ui/desktop/request/request.dart';
import 'package:network_proxy/utils/listenable_list.dart';

///请求序列 列表
/// @auth wanghongen
class RequestSequence extends StatefulWidget {
  final ListenableList<HttpRequest> container;
  final ProxyServer proxyServer;
  final bool displayDomain;
  final Function(List<HttpRequest>)? onRemove;

  const RequestSequence(
      {super.key, required this.container, required this.proxyServer, this.displayDomain = true, this.onRemove});

  @override
  State<StatefulWidget> createState() {
    return RequestSequenceState();
  }
}

class RequestSequenceState extends State<RequestSequence> with AutomaticKeepAliveClientMixin {
  late Configuration configuration;

  ///显示的请求列表 最新的在前面
  Queue<HttpRequest> view = Queue();
  bool changing = false;

  //搜索的内容
  SearchModel? searchModel;

  //关键词高亮监听
  late VoidCallback highlightListener;

  @override
  void initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;
    view.addAll(widget.container.source.reversed);

    highlightListener = () {
      //回调时机在高亮设置页面dispose之后。所以需要在下一帧刷新，否则会报错
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        highlightHandler();
      });
    };
    KeywordHighlightDialog.keywordsController.addListener(highlightListener);
  }

  changeState() {
    //防止频繁刷新
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          changing = false;
        });
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    KeywordHighlightDialog.keywordsController.removeListener(highlightListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.separated(
        cacheExtent: 1500,
        separatorBuilder: (context, index) => Divider(thickness: 0.2, height: 0, color: Theme.of(context).dividerColor),
        itemCount: view.length,
        itemBuilder: (context, index) {
          return RequestWidget(
            view.elementAt(index),
            index: view.length - index,
            trailing: appIcon(view.elementAt(index)),
            proxyServer: widget.proxyServer,
            displayDomain: widget.displayDomain,
            remove: (requestWidget) {
              setState(() {
                view.remove(requestWidget.request);
              });
              widget.onRemove?.call([requestWidget.request]);
            },
          );
        });
  }

  Widget? appIcon(HttpRequest request) {
    var processInfo = request.processInfo;
    if (processInfo == null) {
      return null;
    }

    return futureWidget(
        processInfo.getIcon(),
        (data) =>
            data.isEmpty ? const SizedBox() : Image.memory(data, width: 23, height: Platform.isWindows ? 16 : null));
  }

  ///高亮处理
  highlightHandler() {
    setState(() {});
  }

  ///添加请求
  add(HttpRequest request) {
    ///过滤
    if (searchModel?.isNotEmpty == true && !searchModel!.filter(request, request.response)) {
      return;
    }

    view.addFirst(request);
    changeState();
  }

  ///添加响应
  addResponse(HttpResponse response) {
    if (searchModel == null || searchModel!.isEmpty || response.request == null) {
      changeState();
      return;
    }

    //搜索视图
    if (searchModel?.filter(response.request!, response) == true) {
      if (!view.contains(response.request)) {
        view.addFirst(response.request!);
        changeState();
      }
    }
  }

  ///过滤
  void search(SearchModel searchModel) {
    this.searchModel = searchModel;
    if (searchModel.isEmpty) {
      view = Queue.of(widget.container.source.reversed);
    } else {
      view = Queue.of(widget.container.where((it) => searchModel.filter(it, it.response)).toList().reversed);
    }
    setState(() {});
  }

  remove(List<HttpRequest> list) {
    setState(() {
      view.removeWhere((element) => list.contains(element));
    });
  }

  clean() {
    setState(() {
      view.clear();
    });
  }
}