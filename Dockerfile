FROM golang:alpine

## 为我们的镜像设置必要的环境变量
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
	GOPROXY="https://goproxy.cn,direct"
##
## 移动到工作目录：/home/www/shoptool 这个目录 是你项目代码 放在linux上
## 这是我的代码跟目录
## 你们得修改成自己的
WORKDIR /home/www/mt
#
## 将代码复制到容器中
COPY . .
#
#RUN go get -u github.com/swaggo/swag/cmd/swag
#
#RUN swag init
#
RUN go mod tidy
#
## 将我们的代码编译成二进制可执行文件  可执行文件名为 app
RUN go build -o app ./main.go

## 移动到用于存放生成的二进制文件的 /dist 目录
WORKDIR /dist

## 这个步骤可以略  因为项目是引用到了 外部静态资源
RUN cp -r /home/www/mt/app .
# 声明服务端口
EXPOSE 8090

# 启动容器时运行的命令
CMD ["/dist/app"]
