PROTO_ROOT := Sources/Transport/Proto
OUT_DIR    := Sources/Transport/Generated
PROTO_FILES := $(shell find $(PROTO_ROOT) -name '*.proto')

PROTOC_GEN_SWIFT      := $(shell which protoc-gen-swift)
PROTOC_GEN_GRPC_SWIFT := $(shell which protoc-gen-grpc-swift-2)

.PHONY: proto clean-proto

proto: $(PROTO_FILES)
	@mkdir -p $(OUT_DIR)
	protoc \
		--proto_path=$(PROTO_ROOT) \
		--plugin=protoc-gen-swift=$(PROTOC_GEN_SWIFT) \
		--swift_out=$(OUT_DIR) \
		--swift_opt=Visibility=Internal \
		--plugin=protoc-gen-grpc-swift-2=$(PROTOC_GEN_GRPC_SWIFT) \
		--grpc-swift-2_out=$(OUT_DIR) \
		--grpc-swift-2_opt=Visibility=Internal \
		--grpc-swift-2_opt=Server=true \
		--grpc-swift-2_opt=Client=true \
		$(PROTO_FILES)
	@echo "[ OK ] Proto generation complete -> $(OUT_DIR)/"

clean-proto:
	rm -rf $(OUT_DIR)
