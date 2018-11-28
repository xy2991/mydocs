# coding=utf-8
import docker
import argparse
import sys
# import os
import json


class DeploymentClass(object):
    def __init__(self, host, service, image):
        self.host = host
        self.service = service
        self.image = image

    def get_client(self):
        #    global client
        cert_path = "./certs.d/" + self.host
        envs = {
            'DOCKER_HOST': 'https://' + self.host + ':2376',
            'DOCKER_TLS_VERIFY': cert_path,
            'DOCKER_CERT_PATH': cert_path
        }
        client = docker.from_env(environment=envs)
        return client

    def get_depoly_info(self):
        json_file = './compose.d/' + self.service + '.json'
        with open(json_file) as f:
            data = json.load(f)
            kwargs = data[self.host]
        return kwargs

    def pull_image(self):
        client = self.get_client()
        try:
            client.login(username='ichangan', password='Ichangan123', registry='10.64.250.16/titanotp')
            client.images.pull(self.image)
        except docker.errors.APIError:
            # print docker.errors.APIError
            print "pull image error. Image:" + self.image + " may not exist, or check the disk space."
            sys.exit(1)
        else:
            print "pull image" + self.image + " succeed."

    def container_remove(self):
        client = self.get_client()
        info = self.get_depoly_info()
        try:
            container = client.containers.get(info['name'])
            if container.status == "running":
                try:
                    container.stop()
                except docker.errors.APIError:
                    print "The container stops failing"
                    sys.exit(97)
                else:
                    print "The container has stopped"
            try:
                rm_args = {'force': True}
                container.remove(**rm_args)
            except docker.errors.APIError:
                print "delete container failed"
                #        sys.exit(95)
            else:
                print "delete container: " + info['name'] + " succeed"
        except docker.errors.NotFound:
            print "container not found."
            pass
            # sys.exit(96)
        except docker.errors.APIError:
            print "Failed to get container information."

    def container_run(self):
        client = self.get_client()
        info = self.get_depoly_info()
        try:
            self.pull_image()
            client.containers.run(self.image,  **info)
        except docker.errors.ImageNotFound:
            print "image not found"
            sys.exit(98)
        except docker.errors.APIError, e:
            print "Container creation failed"
            print str(e)
            sys.exit(99)
        else:
            print "The container: " + info['name'] + " runs successfully."

    def clean_old_image(self):
        client = self.get_client()
        image_name = self.image.split(':', 1)[0]
        image_tag = self.image.split(':', 1)[1]
        container_images = []
        print "checking image:" + image_name
        try:
            image_list = client.images.list()  # 列出所有的镜像
            container_list = client.containers.list()  # 只会列出正在使用的容器
            for c in container_list:
                container_image = c.attrs['Config']['Image']
                if container_image not in container_images:
                    container_images.append(container_image)
            for i in image_list:
                checking_image_name = i.tags[0].split(':', 1)[0]
                checking_image_tag = i.tags[0].split(':', 1)[1]
                if checking_image_name == image_name and checking_image_tag != image_tag:
                    image_to_remove = i.tags[0]
                    if image_to_remove not in container_images:
                        print "removing: " + image_to_remove
                        client.images.remove(image_to_remove, {"force": True})
        except docker.errors.APIError:
            print "Failed to clean " + self.service + "'s redandent images"
            #        sys.exit(95)
            pass
        except IndexError:
            print "check the images on this host,there maybe some images with <none> tag"
        else:
            print "Successfully clean the redandent images"

    def exec_deploy(self):
        self.container_remove()
        self.container_run()
        self.clean_old_image()


def get_args():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--hosts', '-o', required="true",
                        help='target ip address or hostname. Example: 10.64.13.82')
    parser.add_argument('--service', '-s', required="true",
                        help='service name. Example: member-service')
    parser.add_argument('--image', '-i', required="true",
                        help='tag name. Example: 10.64.250.16/titanotp/consult:master.134')
    return parser.parse_args()


def main():
    args = get_args()
    hosts = args.hosts.split(',')
    service = args.service
    image = args.image
    print(hosts, service, image)
    for host in hosts:
        job = DeploymentClass(host, service, image)
        job.exec_deploy()


if __name__ == '__main__':
    main()
