FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get --quiet --assume-yes install build-essential g++ gdb swig2.0 mercurial scons
RUN apt-get --quiet --assume-yes install git-core curl python-scipy python-matplotlib python-tables imagemagick python-opencv python-bs4
RUN apt-get --quiet --assume-yes install perl-doc groff

# RUN apt-get -q -y install cpanminus
# RUN cpanm utf8::all Data::Printer

WORKDIR /opt/

RUN git clone https://github.com/tmbdev/ocropy.git

WORKDIR /opt/ocropy

RUN apt-get --quiet --yes install

WORKDIR /opt/ocropy/models

RUN curl --remote-name http://www.tmbdev.net/en-default.pyrnn.gz

WORKDIR /opt/ocropy

# ADD . /opt/ocrocis/

RUN sudo python setup.py install

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV HOST_UNAME $HOST_UNAME

RUN groupadd --force --non-unique --gid $HOST_GID dockergroup

RUN [ "useradd", "--uid", "$HOST_UID", "--non-unique", "--gid", "sudo", "-G", "$HOST_GID", "-s", "/bin/bash", "-p", "'*'", "-md", "/home/docker", "docker" ]
RUN [ "passwd", "-d", "docker" ]

#RUN [ "echo", "'export", "HOST_UNAME=$HOST_UNAME'", ">>", "/home/docker/.bash_profile" ]

#RUN [ "useradd", "--uid", "$HOST_UID", "--non-unique", "--gid", "sudo", "--gid", "$HOST_GID", "-s", "/bin/bash", "-p", "'*'", "docker" ]

# RUN [ "groupadd", "--force", "--gid", "$GID", "dockergroup" ]
# RUN  [[ "$HOST_UNAME" -eq "Linux" ]] && groupadd --force --gid $GID dockergroup
#RUN [ "useradd", "--uid", "$HOST_UID", "--gid", "sudo", "--gid", "$GID", "-p", "'*'", "docker" ]
# RUN useradd --uid $DEV_UID docker --gid sudo -p '*'

#RUN [ "adduser", "docker", "sudo", "2>&1", ">/dev/null" ]
#RUN echo 'docker  ALL=(ALL:ALL) ALL' >> /etc/sudoers

RUN echo 'docker  ALL=NOPASSWD: ALL' >> /etc/sudoers
#RUN echo 'export HOST_UNAME=$HOST_UNAME' >> /home/docker/.bashrc
RUN echo $HOST_UNAME > /home/docker/host_uname

# ADD $PWD/lib/entry.sh /lib/

# CMD [ "lib/linux_groupadd.sh" ]

ENTRYPOINT ["/opt/ocrocis/dockerentry.sh"]
#CMD ["/bin/bash"]
