#!/bin/bash

#接收端口
if [ -z "$1" ]; then
  echo "you must input a port"
  exit 0
fi

if [ -z "$2" ]; then
  echo "you must input a image_name"
  exit 0
fi

if [ -z "$3" ]; then
  echo "you must input a container_name"
  exit 0
fi

image_name=$2
container_name=$3
container_port=$1

#读取镜像tag
old_tags=$(docker images --filter=reference="${image_name}" --format "{{.Tag}}")
#删除多余镜像
# shellcheck disable=SC2206
array=(${old_tags//," " /})
old_tag="${array[-1]}"
# shellcheck disable=SC2068
for i in ${array[@]}; do
  # shellcheck disable=SC2154
  if [ "$i" == "${old_tag}" ]; then
    continue
  fi
  echo "删除镜像" "$i"
  docker rmi "${image_name}":"${i}"
  # shellcheck disable=SC2181
  if [ $? != 0 ]; then
    echo "删除失败:tag=""${i}"
  else
    echo "删除成功:tag=""${i}"
  fi
done

echo old_tag="${old_tag}"
old_image_id=$(docker images -q --filter reference="${image_name}":"${old_tag}")
echo old_image_id="${old_image_id}"
if [ "${old_tag}" != "" ]; then
  tag="${old_tag}"
else
  tag=1
fi

# shellcheck disable=SC2034
new_tag=$((tag + 1))
#构建本次镜像
#构建镜像
docker build -t "${image_name}":"${new_tag}" .
# shellcheck disable=SC2181
if [ $? != 0 ]; then
  echo "新构建镜像失败"
  exit 2
fi
echo "构建镜像成功"

#关闭上次容器
old_container_id=$(docker ps -aq --filter name="${container_name}")
if [ "${old_container_id}" != "" ]; then
  # shellcheck disable=SC2006
  exist=$(docker inspect --format '{{.State.Running}}' "${container_name}")
  #容器已经被启动了
  if [ "${exist}" == "true" ]; then
    docker stop "${old_container_id}"
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
      echo "停止旧容器失败"
      exit 2
    fi
    echo "停止旧容器成功"
  fi
  #删除旧容器
  if [ "${old_container_id}" != "" ]; then
    docker rm -f "${old_container_id}"
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
      echo "删除旧容器失败"
      exit 2
    fi
    echo "删除旧容器成功"
  fi

fi

#启动本次容器
new_container_id=$(docker run --name "${container_name}" -p "${container_port}" -d "${image_name}":"${new_tag}")
# shellcheck disable=SC2181
if [ $? != 0 ]; then
  echo "新容器启动失败"
  #容器回滚
  #关闭本次容器
  if [ "${new_container_id}" != "" ]; then
    docker rm -f "${new_container_id}"
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
      echo "删除新容器失败"
      exit 2
    fi
    echo "删除新容器成功"
  fi
  #删除新镜像
  new_image_id=$(docker images -q --filter reference="${image_name}":"${new_tag}")
  if [ "${new_image_id}" != "" ]; then
    docker rmi -f "${new_image_id}"
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
      echo "删除新镜像失败"
      exit 2
    fi
    echo "删除新镜像成功"
  fi
  if [ "${old_image_id}" != "" ]; then
    #启动上次容器
    docker run --name "${container_name}" -p "${container_port}" -d "${image_name}":"${old_tag}"
    if [ $? != 0 ]; then
      echo "容器回滚失败"
      exit 2
    else
      echo "容器回滚成功"
    fi
  else
    echo "没有上个版本镜像不能回滚"
    exit 2
  fi

else
  echo "新容器启动成功"

  #删除旧镜像
  echo old_image_id="${old_image_id}"
  if [ "${old_image_id}" != "" ]; then
    docker rmi -f "${old_image_id}"
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
      echo "删除旧镜像失败"
      exit 2
    fi
    echo "删除旧镜像成功"
  else
    echo "没有旧镜像"
  fi
fi
