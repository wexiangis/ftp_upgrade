host:=arm-linux-gnueabihf

target:wput wget
	@cp ./wput-0.6.1/wput ./
	@cp ./wget-1.15/src/wget ./

wget:
	@tar -xzf ./wget-1.15.tar.gz && \
	cd ./wget-1.15 && \
	./configure --host=$(host) --without-ssl && \
	make && \
	cd -

wput:
	@tar -xzf ./wput-0.6.1.tgz && \
	cd ./wput-0.6.1 && \
	./configure --host=$(host) && \
	make && \
	cd -

clean:
	@rm ./wput-0.6.1 ./wget-1.15 -rf